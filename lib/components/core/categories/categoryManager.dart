// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the COPYING file.

// This is a port of "Image Filters with Canvas" to Dart.
// See: http://www.html5rocks.com/en/tutorials/canvas/imagefilters/

library categorymanager;

import '../photo/photo.dart';
import 'facesCategory.dart' as faces;
import 'toningCategory.dart' as toning;
import 'similarCategory.dart' as similar;
import 'dayMomentCategory.dart' as dayMoment;
import 'qualityCategory.dart' as quality;
import 'category.dart';
import 'package:observe/observe.dart';
import '../auxiliarFunctions/pixelWorkflow.dart';

final _pixelWorkflow = PixelWorkflow.get();

class CategoryManager extends Object with Observable {
   
  /**
   * Singleton
   */
  static CategoryManager _instance; 
  final List<Category> categories = toObservable(new Set());

  CategoryManager._() {
    categories.add(faces.FacesCategory.get());
    categories.add(toning.ToningCategory.get());
    categories.add(similar.SimilarCategory.get());
    categories.add(dayMoment.DayMomentCategory.get());
    categories.add(quality.QualityCategory.get());
  }

  static CategoryManager get() {
    if (_instance == null) {
      _instance = new CategoryManager._();
    }
    return _instance;
  }
                                          
  /**
   * Pipeline to extract categories from photos
   */ 
  void categoriesPipeline(List<Photo> photosToAnalyze){
    if(photosToAnalyze.isNotEmpty){
      if(_pixelWorkflow.analyzePixels(photosToAnalyze)){
        categories.forEach((category){
          category.work(photosToAnalyze);
        }); 
      }
    }
  }
}