import os
import sys
import time
import argparse
import importlib
import numpy as np
import pandas as pd

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
import tensorflow as tf

from Envelope import getEnvelopeResult, generate_counter_example
from Utils import readConfigurations

def output(model, datapoint):
    x_point = pd.DataFrame(datapoint)
    return model.predict(x_point.transpose())

def getEnvelopePredictions(instance, config):
    configurations['weight_files'] = os.path.dirname(configurations['model_dir'])+"/"
    model_file_h5 = configurations['model_dir'] + "model.h5"
    model = tf.keras.models.load_model(model_file_h5)
    
    f_x = output(model, instance)[0][0]
    prediction = f_x
    print("Model prediction:", prediction)
    
    counter_example_upper, _, _, _ = generate_counter_example(configurations, counter_example_generator_upper, instance, 0, 0, f_x, 0)
    
    if counter_example_upper is not None:
        print("Upper counter-example:", counter_example_upper.values)
        upper_envelope_prediction = output(model, counter_example_upper)[0][0]
    else:
        upper_envelope_prediction = f_x
        print("No upper counter-example found.")
    print("Monotone upper envelope prediction:", upper_envelope_prediction)

    counter_example_lower, _, _, _ = generate_counter_example(configurations, counter_example_generator_lower, instance, 0, 0, f_x, 0)
    if counter_example_lower is not None:
        print("Lower counter-example:", counter_example_lower.values)
        lower_envelope_prediction = output(model, counter_example_lower)[0][0]
    else:
        lower_envelope_prediction = f_x
        print("No lower monotone prediction")
    print("Monotone lower envelope prediction:", lower_envelope_prediction)

    return prediction#, upper_envelope_prediction #, lower_envelope_prediction

parser = argparse.ArgumentParser(description='Envelope Prediction')
parser.add_argument('-c', '--config_file', metavar='c', type=str,
    help='configuration file')
parser.add_argument('-i', '--instance', metavar='i', type=str,
    help='instance')

args = parser.parse_args()
instance = args.instance.split(",")
instance = [float(x) for x in instance]

config_file = args.config_file
configurations = readConfigurations(config_file)

instance = pd.Series(instance, index=configurations["feature_names"], dtype=np.float64)

#----- import solver functions --------
counter_example_generator_upper = importlib.__import__(configurations['solver']).counter_example_generator_upper_env
counter_example_generator_lower = importlib.__import__(configurations['solver']).counter_example_generator_lower_env

#------------- COMET ------------------
getEnvelopePredictions(instance, configurations)