import pandas as pd
import numpy as np

from anchor import anchor_tabular
import subprocess

import argparse
import time
import sklearn

import pickle
import getopt
import os, sys
from dataset import Dataset
import time
from sklearn.preprocessing import LabelEncoder

datasets = ['bankruptcy-risk.csv', 'pima.arff']

def parse_options():
    """
        Parses command-line option
    """

    try:
        opts, args = getopt.getopt(sys.argv[1:], 'h:m:d:', ['help', 'witharg'])
    except getopt.GetoptError as err:
        sys.stderr.write(str(err).capitalize())
        usage()
        sys.exit(1)

    # target model
    model = None
    dataset = None

    for opt, arg in opts:
        if opt in ('-h', '--help'):
            usage()
            sys.exit(0)
        elif opt in ('-m', '--model'):
            model = str(arg)
        elif opt in ('-d', '--dataset'):
            dataset = str(arg)
        else:
            assert False, 'Unhandled option: {0} {1}'.format(opt, arg)

    return model, dataset, [float(v) for v in args[0].strip().split(',')]

def usage():
    """
        Prints usage message.
        """

    print('Usage:', os.path.basename(sys.argv[0]), '[options] comma-separated-values')
    print('Options:')
    print('        -m, --model=<string>    Path to monoboost model')
    print('        -d, --dataset=<string>  Path to dataset')
    print('        -h, --help              Show this message')


def classify(X):
    cat = list()
    for i in range(X.shape[1]):
        if len(np.unique(X[:, i])) < (X.shape[0] / 2):
            cat.append(i)
    return cat

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

if __name__ == "__main__":
    
    model, dataset, inst = parse_options()

    # loading the pickle object and extracing the model
    with open(model, 'rb') as fobj:
        mb_clf = pickle.load(fobj)
    
    data = Dataset(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'datasets', dataset))
    
    X, y = data.as_arrays()
    X = np.array(X)
    y = np.array(y)
    inst = np.array(inst)

    X_train, X_test, y_train, y_test = sklearn.model_selection.train_test_split(X, y)

    cat_columns = classify(X)

    class_names = np.unique(y).astype(str)
    feature_names = data.attr[:-1]
    cat_names = dict()
    X_enc, encoders = encode(X, cat_columns)
    for i, enc in encoders.items():
        cat_names[i] = enc.classes_.astype(str).tolist()

    predict_fn = mb_clf.predict
    anchor_explainer = anchor_tabular.AnchorTabularExplainer(class_names, feature_names, X, cat_names)
    enc_inst, _ = encode(np.array([inst]), cat_columns, encoders)
    start = time.time()
    anchor_explanation = anchor_explainer.explain_instance(enc_inst[0], predict_fn, threshold=0.95)
    print("Time elapsed:", time.time() - start)
    print("Anchor explanation:", anchor_explanation.names())
    print("Anchor features:", anchor_explanation.features())
