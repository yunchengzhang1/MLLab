#!/usr/bin/python

from pymongo import MongoClient
import tornado.web

import base64

from tornado.web import HTTPError
from tornado.httpserver import HTTPServer
from tornado.ioloop import IOLoop
from tornado.options import define, options

from basehandler import BaseHandler

import turicreate as tc

import pandas as pd

import pickle
from bson.binary import Binary
import json
import numpy as np
import os

class PrintHandlers(BaseHandler):
    def get(self):
        '''Write out to screen the handlers used
        This is a nice debugging example!
        '''
        self.set_header("Content-Type", "application/json")
        self.write(self.application.handlers_string.replace('),','),\n'))

class UploadLabeledDatapointHandler(BaseHandler):
    def post(self):
        '''Save data point and class label to database
        '''
        data = json.loads(self.request.body.decode("utf-8"))
        
        encodedImage = data['feature']
        
        label = data['label']
        sess = data['dsid']
        
        dbid = self.db.labeledinstances.insert_one(
            {
                "feature": encodedImage,
                "label": label,
                "dsid": sess
            }
        )

        # vals = data['feature']
        # fvals = [float(val) for val in vals]
        # label = data['label']
        # sess  = data['dsid']

        # dbid = self.db.labeledinstances.insert_one(
        #     {"feature":fvals,"label":label,"dsid":sess}
        #     );
        self.write_json({"id":str(dbid),
            "feature":["encoded image " + str(encodedImage) + " received"],
            "label":label})

class RequestNewDatasetId(BaseHandler):
    def get(self):
        '''Get a new dataset ID for building a new dataset
        '''
        a = self.db.labeledinstances.find_one(sort=[("dsid", -1)])
        if a == None:
            newSessionId = 1
        else:
            newSessionId = float(a['dsid'])+1
        self.write_json({"dsid":newSessionId})

class UpdateModelForDatasetId(BaseHandler):
    def get(self):
        '''Train a new model (or update) for given dataset ID
        '''
        dsid = self.get_int_arg("dsid",default=0)

        data = self.get_features_and_labels_as_SFrame(dsid)

        # fit the model to the data
        acc = -1
        best_model = 'unknown'
        if len(data)>0:
            
            model = tc.logistic_classifier.create(data,target='target',verbose=0)# training
            yhat = model.predict(data)
            self.clf[dsid] = model
            acc = sum(yhat==data['target'])/float(len(data))
            # save model for use later, if desired
            model.save('../models/turi_model_dsid%d'%(dsid))
        else:
            print("data length 0")
            

        # send back the resubstitution accuracy
        # if training takes a while, we are blocking tornado!! No!!
        self.write_json({"resubAccuracy":acc})

    def get_features_and_labels_as_SFrame(self, dsid):
        features = []
        labels = []
        
        decodedFeatures = []
        
        for a in self.db.labeledinstances.find({"dsid": dsid}):
            features.append(a['feature'])
            labels.append(a['label'])
        
        for feature in features:
            decodedImage = base64.b64decode(feature)
        
            fh = open("decodedImage.jpg", "wb")
            fh.write(decodedImage)
            fh.close()
            
            url = "./decodedImage.jpg"
            # sframe_image = tc.image_analysis.load_images(url, "auto", with_path = False, recursive = True)
            # sframe_image = tc.SArray([tc.Image(url)])
            
            decodedFeatures.append(decodedImage)
        
        data = {
            'target': labels,
            'sequence': np.array(decodedFeatures)
        }
        
        return tc.SFrame(data = data)
    
    # def get_features_and_labels_as_SFrame(self, dsid):
    #     # create feature vectors from database
    #     features=[]
    #     labels=[]
    #     for a in self.db.labeledinstances.find({"dsid":dsid}): 
    #         features.append([float(val) for val in a['feature']])
    #         labels.append(a['label'])

    #     # convert to dictionary for tc
    #     data = {'target':labels, 'sequence':np.array(features)}

    #     # send back the SFrame of the data
    #     return tc.SFrame(data=data)

class PredictOneFromDatasetId(BaseHandler):
    def post(self):
        '''Predict the class of a sent feature vector
        '''
        data = json.loads(self.request.body.decode("utf-8"))    
        fvals = self.get_features_as_SFrame(data['feature'])
        dsid  = data['dsid']

        # load the model from the database (using pickle)
        # we are blocking tornado!! no!!
        if dsid not in self.clf:
            print('loading model from file')
            if os.path.exists('../models/turi_model_dsid%d'%(dsid)):
                self.clf[dsid] = tc.load_model('../models/turi_model_dsid%d'%(dsid))
            else:
                print('could not load file with dsid%d'%(dsid))
                self.write_json({"prediction": -404})
                return
        # if(self.clf == []):
        #     print('Loading Model From file')
        #     self.clf = tc.load_model('../models/turi_model_dsid%d'%(dsid))
  

        predLabel = self.clf[dsid].predict(fvals)
        print(np.unique(predLabel, return_counts=True))
        self.write_json({"prediction":str(predLabel[0])})

    def get_features_as_SFrame(self, vals):
        # create feature vectors from array input
        # convert to dictionary of arrays for tc

        # tmp = [float(val) for val in vals]
        # tmp = np.array(tmp)
        # tmp = tmp.reshape((1,-1))
        # data = {'sequence':tmp}
        
        decodedImage = base64.b64decode(vals)
    
        fh = open("decodedImage.jpg", "wb")
        fh.write(decodedImage)
        fh.close()
        data = {'sequence': decodedImage}

        # send back the SFrame of the data
        return tc.SFrame(data)
