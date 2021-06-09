import pandas as pd
import numpy as np

from anchor import anchor_tabular
import subprocess

import argparse
import time
import sklearn

if __name__ == "__main__":
    """
    parser = argparse.ArgumentParser(description='Anchor GRDC')
    parser.add_argument('-i', '--instance', metavar='i', type=str,help='instance')

    args = parser.parse_args()
    instance = args.instance.split(",")
    instance = np.array([int(x) for x in instance])
    """

    df = pd.read_csv("./bench/datasets/StudentGrades/StudentGrades.csv")
    X = df.drop(df.columns[-1], axis=1)
    X = X.drop("Inst", axis=1)

    #X[X.columns[-1]] = X[X.columns[-1]] -1
    #X = X-1
    y = df[df.columns[-1]]
    #le = LabelEncoder().fit(y)
    #y = le.transform(y)
    X_train, X_test, y_train, y_test = sklearn.model_selection.train_test_split(X, y)
    class_names = ["A", "B", "C", "D", "E", "F"]
    #feature_names = np.arange(len(df.columns).astype(str)
    feature_names = X.columns
    cat_names = dict()
    for i in range(X.shape[1]):
        min_ = np.min(X.values[:, i])
        max_ = np.max(X.values[:, i])
        cat_names[i] = np.arange(min_, max_ + 1).astype(str).tolist()
        #cat_names[i] = np.unique(X.values[:, i].astype(str)).tolist()
    #print(feature_names, cat_names, len(cat_names), len(X.values[0]))

    def predict_fn(x):
        preds = list()
        def ite(a, b, c):
            return b if a else c
        def grdc_perdict(x):
            S = max(0.3*x[0] + 0.6*x[1] + 0.1*x[2], x[3])
            M = ite(S >= 9, 'A',
                    ite(S >= 7, 'B', 
                        ite(S>=5, 'C', 
                            ite(S >= 4, 'D', 
                                ite(S>=2, 'E', 'F')))))
            return M
        if len(x.shape) == 1:
            pred = grdc_perdict(x)
            preds.append(pred)
        else:
            for inst in x:
                pred = grdc_perdict(inst)
                preds.append(pred)
        return np.array(preds)
   
    anchor_explainer = anchor_tabular.AnchorTabularExplainer(class_names, feature_names, X.values, cat_names)
    indexes = pd.read_csv("./exps/student-grades-list", header=None).values
    indexes = indexes.reshape(1,-1)[0]
    for index in indexes:
        print("------------------------------------------")
        start = time.time()
        row = X.iloc[index-1].values
        print("INDEX", index, "ROW", row)
        anchor_explanation = anchor_explainer.explain_instance(row, predict_fn, threshold=0.95, desired_label=None)
        anchor_expl = anchor_explanation.features()
        print("Anchor Explanation:", np.array(anchor_expl))
        print("Time elapsed:", time.time() - start, "s.")