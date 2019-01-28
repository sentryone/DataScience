import pandas as pd
import numpy as np
import sys
import time
import os
from collections import Counter 
from sklearn.model_selection import train_test_split 
from sklearn.tree import DecisionTreeClassifier
from sklearn.metrics import accuracy_score
from sklearn import tree
from imblearn.over_sampling import RandomOverSampler
from sklearn.tree import export_graphviz

# enter full file path to beer_joined.csv here
# ex: "C:/Users/beers_joined.csv"
input_filepath = ""

# retrieve data file, replace certain characters due to UnicodeEncodeError, and remove NA values
try:
    data = pd.read_csv(input_filepath, sep = ",", encoding = 'utf-8')
    data["name"] = data["name"].str.replace(u'\u2019',"'")
    data["style"] = data["style"].str.replace(u'\u2019',"'")
    data = data.dropna()
except Error:
    print("Error importing file")
finally:
    print("Successfully imported file")

# count values in each class 
data["class_name"].value_counts() 

# remove Other class
data = data[data["class_name"] != "Other"]

# define target and features 
target = data["class_name"]
features = data[["abv", "ibu"]]

# print original distribution of targets
print("Original distribution {}".format(Counter(target)))

# Oversample based on class labels
ros = RandomOverSampler(random_state = 100, ratio = "auto")

X_resampled, y_resampled = ros.fit_sample(features, target)

# print new distribution of targets
print("New distribution {}".format(Counter(y_resampled)))

# convert numpy arrays (the output from resampling) into Pandas Dataframes
res_features = pd.DataFrame(data = X_resampled, index = X_resampled[0:,0], columns = ["abv", "ibu"])
res_target = pd.DataFrame(data = y_resampled, index = y_resampled[0:], columns = ["class_name"])

# split features and target into test and train datasets
res_features_train, res_features_test, res_target_train, res_target_test = train_test_split(res_features, res_target, test_size = .25, random_state = 100)

# create the decision tree
tree_entropy = DecisionTreeClassifier(criterion = "entropy", random_state = 100, max_depth = 3, min_samples_leaf = 20, min_samples_split = 50)

# fit the decision tree
tree_entropy.fit(res_features_train, res_target_train)

# predict values from the test dataset
target_prediction_entropy = tree_entropy.predict(res_features_test)

# print the accuracy score
print("Entropy accuracy is ", round(accuracy_score(res_target_test, target_prediction_entropy) * 100, 2))

# specify output directory for graphviz file
# ex: "C:/Users/"
output_filepath = "" 

# open and write the decision tree output to the directory listed above
entropy_output = open(output_filepath + "decision_tree_graphviz.dot", 'w')
export_graphviz(tree_entropy, out_file = entropy_output, feature_names = res_features_test.columns, class_names = tree_entropy.classes_)
entropy_output.close()

# Website for viewing the tree output
#   - http://webgraphviz.com/
# 
# Instructions:
#   - Open the .dot file that was generated in the above code using a text editor (notepad works fine)
#   - Copy/Paste the contents into the webgraphviz webpage 