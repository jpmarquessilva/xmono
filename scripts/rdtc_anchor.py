import pandas as pd
import numpy as np

from anchor import anchor_tabular
import subprocess

import argparse
import time
import sklearn

if __name__ == "__main__":
    """
    parser = argparse.ArgumentParser(description='Anchor RDTC')
    parser.add_argument('-i', '--instance', metavar='i', type=str,help='instance')

    args = parser.parse_args()
    instance = args.instance.split(",")
    instance = np.array([int(x) for x in instance])
    """

    df = pd.read_csv("./bench/datasets/BankruptcyRisk/BankruptcyRisk.csv")
    X = df.drop(df.columns[-1], axis=1)
    X = X.drop("Sample", axis=1)
    X = X-1
    y = df[df.columns[-1]]
    X_train, X_test, y_train, y_test = sklearn.model_selection.train_test_split(X, y)
    class_names = [1, 2, 3]

    feature_names = X.columns
    cat_names = dict()
    for i in range(X.shape[1]):
        min_ = np.min(X.values[:, i])
        max_ = np.max(X.values[:, i])
        cat_names[i] = np.arange(min_, max_ + 1).astype(str).tolist()
        #cat_names[i] = np.unique(X.values[:, i].astype(str)).tolist()

    nofcalls = []
    def predict_fn(x):
        preds = list()
        def ite(a, b, c):
            return b if a else c
        def rdtc_predict(x):
            return ite(x[6]<=3,
                ite(x[5]<=1, 
                    ite(x[4], 1, 
                        ite(x[7], 1, 2)), 2),
                ite(x[8]<=3, 2, 3))
        if len(x.shape) == 1:
            pred = rdtc_predict(x)
            preds.append(pred)
            nofcalls[-1] += 1
        else:
            for inst in x:
                pred = rdtc_predict(inst)
                preds.append(pred)
                nofcalls[-1] += 1
        return np.array(preds)
   

    anchor_explainer = anchor_tabular.AnchorTabularExplainer(class_names, feature_names, X.values, cat_names)
    indexes = pd.read_csv("./exps/bankruptcy-risk-list", header=None).values
    indexes = indexes.reshape(1,-1)[0]
    f = open("./rdtc_anchor.txt", "w")
    for index in indexes:
        nofcalls.append(0)
        f.write("------------------------------------------\n")
        start = time.time()
        row = X.iloc[index-1].values
        f.write("INDEX " + str(index) + " ROW ")
        f.write("[" + ",".join([str(x) for x in row+1]) + "]\n")
        anchor_explanation = anchor_explainer.explain_instance(row, predict_fn, threshold=0.95, desired_label=None)
        anchor_expl = anchor_explanation.features()
        f.write("Anchor explanation: " + "[" + ",".join([str(x) for x in anchor_expl]) + "]\n")
        #print("Anchor Explanation:", anchor_expl)
        f.write("Number of calls: " + str(nofcalls[-1]) + "\n")
        f.write("Time elapsed: " + str(round(time.time() - start, 4)) + "s.\n")
        #print("Time elapsed:", time.time() - start, "s.")
    f.close()