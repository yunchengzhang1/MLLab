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
        decodedImage = base64.b64decode(encodedImage)
        #print(encodedImage)
        label = data['label']
        sess  = data['dsid']
        
        fh = open("imageToSave.jpg", "wb")
        fh.write(decodedImage)
        fh.close()
        
        '''
        url = "./imageToSave.jpg"
        sframe_image = tc.image_analysis.load_images(url, "auto", with_path = False, recursive = True)
        print(sframe_image)
#        print(tc.image_analysis.load_images(decodedImage, "auto"))
        
        colourImg = Image.open(decodedImage)
        colourPixels = colourImg.convert("RGB")
        colourArray = np.array(colourPixels.getdata()).reshape(colourImg.size + (3,))
        indicesArray = np.moveaxis(np.indices(colourImg.size), 0, 2)
        allArray = np.dstack((indicesArray, colourArray)).reshape((-1, 5))
        
        
        df = pd.DataFrame(allArray, columns=["y", "x", "red","green","blue"])
        print(df)
        '''
        dbid = self.db.labeledinstances.insert(
    
            {"feature":sframe_image,"label":label,"dsid":sess}
            );
      #  self.write_json({"id":str(dbid),
       #     "feature":[str(len(fvals))+" Points Received",
       #             "min of: " +str(min(fvals)),
      #              "max of: " +str(max(fvals))],
      #      "label":label})

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

            model = tc.classifier.create(data,target='target',verbose=0)# training
            yhat = model.predict(data)
            
            if len(self.clf)==0:
                self.clf = {dsid: model} # setup clf to be dictionary
            else:
                self.clf[dsid] = model
                

            acc = sum(yhat==data['target'])/float(len(data))
            # save model for use later, if desired
#            model.save('../models/turi_model_dsid%d'%(dsid))
            

        # send back the resubstitution accuracy
        # if training takes a while, we are blocking tornado!! No!!
        self.write_json({"resubAccuracy":acc})

    def get_features_and_labels_as_SFrame(self, dsid):
        # create feature vectors from database
        features=[]
        labels=[]
        for a in self.db.labeledinstances.find({"dsid":dsid}): 
            features.append(a['feature']])
            labels.append(a['label'])

        # convert to dictionary for tc
        data = {'target':labels, 'sequence':np.array(features)}


        url = "./imageToSave.jpg"
        sframe_image = tc.image_analysis.load_images(url, "auto", with_path = False, recursive = True)
        print(sframe_image)
        
        # send back the SFrame of the data
        return tc.SFrame(data=data)

class PredictOneFromDatasetId(BaseHandler):
    def post(self):
        '''Predict the class of a sent feature vector
        '''
        data = json.loads(self.request.body.decode("utf-8"))    
        fvals = self.get_features_as_SFrame(data['feature'])
        dsid  = data['dsid']

        # load the model from the database (using pickle)
        # we are blocking tornado!! no!!
        print("predict one")

        if(dsid not in self.clf):
            print("dsid is not in self.clf yet")
            self.write_json({"prediction":"none"})
#            model = tc.load_model('../models/turi_model_dsid%d'%(dsid))
#            print("did load_model('../models/turi_model_dsid%d'%(dsid))")
#            if model is None:
#                    print("model is none")
#                    self.write_json({"prediction":-1})
            #when model exists
#            self.clf[dsid]=model
        else:
            print("model associated with dsid found")
            
            predLabel = self.clf[dsid].predict(fvals);
            self.write_json({"prediction":str(predLabel)})

    def get_features_as_SFrame(self, encodedImage):
        # create string obj for input
        # convert to dictionary of arrays for tc
        tc.image_analysis.load_images()
        tmp = encodedImage
        print("get_features_asSFrame")
        data = {'sequence':tmp}

        # send back the SFrame of the data
        return tc.SFrame(data=data)
