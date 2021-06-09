#!/usr/bin/env python
#-*- coding:utf-8 -*-
##
## mbanchorfb.py
##
##  Created on: Feb 2, 2021
##      Author: Alexey Ignatiev
##      E-mail: alexey.ignatiev@monash.edu
##

# imported modules
#==============================================================================
from anchor import anchor_tabular
from dataset import Dataset
import getopt
import numpy as np
import os
import pandas as pd
import pickle
import sklearn
from sklearn.preprocessing import LabelEncoder
import subprocess
import sys
import time


#
#==============================================================================
def parse_options():
    """
        Parses command-line option
    """

    try:
        opts, args = getopt.getopt(sys.argv[1:], 'd:hm:', ['dataset', 'help', 'model'])
    except getopt.GetoptError as err:
        sys.stderr.write(str(err).capitalize())
        usage()
        sys.exit(1)

    # target model
    dataset = None
    model = None

    for opt, arg in opts:
        if opt in ('-d', '--dataset'):
            dataset = str(arg)
        elif opt in ('-h', '--help'):
            usage()
            sys.exit(0)
        elif opt in ('-m', '--model'):
            model = str(arg)
        else:
            assert False, 'Unhandled option: {0} {1}'.format(opt, arg)

    return dataset, model


#
#==============================================================================
def usage():
    """
        Prints usage message.
        """

    print('Usage:', os.path.basename(sys.argv[0]), '[options] comma-separated-values')
    print('Options:')
    print('        -d, --dataset=<string>    Path to dataset')
    print('        -h, --help                Show this message')
    print('        -m, --model=<string>      Path to monoboost model')


#
#==============================================================================
def classify(X):
    cat = list()
    for i in range(X.shape[1]):
        if len(np.unique(X[:, i])) < (X.shape[0] / 2):
            cat.append(i)
    return cat


#
#==============================================================================
def encode(X, cat_columns, encoders=None):
    X_enc = X.copy()
    if encoders:
        for i, encoder in encoders.items():
            X_enc[:, i] = encoder.transform(X_enc[:, i])
    else:
        encoders = dict()
        for i in cat_columns:
            le = LabelEncoder()
            le.fit(X[:, i])
            encoders[i] = le
            X_enc[:, i] = le.transform(X_enc[:, i])
    return X_enc, encoders


#
#==============================================================================
if __name__ == "__main__":
    dataset, model = parse_options()

    # loading the pickle object and extracing the model
    with open(model, 'rb') as fobj:
        mb_clf = pickle.load(fobj)

    data = Dataset(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'datasets', dataset))

    X, y = data.as_arrays()
    X = np.array(X)
    y = np.array(y)

    X_train, X_test, y_train, y_test = sklearn.model_selection.train_test_split(X, y)

    cat_columns = classify(X)

    class_names = np.unique(y).astype(str)
    feature_names = data.attr[:-1]
    cat_names = dict()
    X_enc, encoders = encode(X, cat_columns)
    for i, enc in encoders.items():
        cat_names[i] = enc.classes_.astype(str).tolist()

    # predict_fn = mb_clf.predict
    nofcalls = []
    def predict_fn(insts):
        cls = []
        for inst in insts:
            # reading the file every time
            with open(model, 'rb') as fobj:
                mb_clf = pickle.load(fobj)
            c = int(round(mb_clf.predict(np.array([inst]))[0]))

            # i = ','.join([str(v) for v in inst])
            # c = subprocess.check_output('./mbrun.py -m {0} {1}'.format(model, i).split(' '), shell=False)

            nofcalls[-1] += 1
            cls.append(float(c))
        return np.array(cls)

    anchor_explainer = anchor_tabular.AnchorTabularExplainer(class_names, feature_names, X_enc, cat_names)

    runtimes, sizes = [], []
    for i, row in enumerate(X, 1):
        print('inst {0}:'.format(i))
        nofcalls.append(0)
        start = time.time()
        enc_row, _ = encode(np.array([row]), cat_columns, encoders)
        anchor_explanation = anchor_explainer.explain_instance(enc_row[0], predict_fn, threshold=0.95)
        print('  anchor explanation:', anchor_explanation.names())
        expl = anchor_explanation.features()
        sizes.append(len(expl))
        print('  anchor features:', expl)
        print('  size:', sizes[-1])
        runtime = time.time() - start
        runtimes.append(runtime)
        print('  calls:', nofcalls[-1])
        print('  time: {0:.2f}'.format(runtime))

    print('avg calls: {0:.2f}'.format(np.mean(np.array(nofcalls))))
    print('avg size: {0:.2f}'.format(np.mean(np.array(sizes))))
    print('avg time: {0:.2f}'.format(np.mean(np.array(runtimes))))
