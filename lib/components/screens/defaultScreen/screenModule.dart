library screenModule;

import 'package:polymer/polymer.dart';
import 'package:route_hierarchical/client.dart';
export 'package:route_hierarchical/client.dart';
import '../../core/database/dataBase.dart';
import '../../core/settings/mementoSettings.dart';
import '../../core/categories/category.dart';
import '../../core/categories/facesCategory.dart' as faces;
import '../../core/categories/toningCategory.dart' as toning;
import '../../core/categories/similarCategory.dart' as similar;
import '../../core/categories/dayMomentCategory.dart' as dayMoment;
import '../../core/categories/qualityCategory.dart' as quality;
import 'dart:html';
import 'dart:core';
import '../../core/photo/photo.dart';
import '../../core/photo/GroupOfPhotos/groupOfPhotos.dart';
import '../../core/photo/GroupOfPhotos/similarGroupOfPhotos.dart';
import '../../core/photo/GroupOfPhotos/colorGroupOfPhotos.dart';
import '../../core/photo/GroupOfPhotos/facesGroupOfPhotos.dart';
import '../../core/photo/GroupOfPhotos/dayMomentGroupOfPhotos.dart';
import '../../core/photo/GroupOfPhotos/qualityGroupOfPhotos.dart';
import '../workers/downloader.dart';
import 'package:bootjack/bootjack.dart';
import 'dart:isolate';
import 'dart:js' as js show JsObject, context;

/**
 * Screen Module
 */
abstract class ScreenModule extends PolymerElement {
  
  String title, description, path;
  Router router;
  MementoSettings settings = MementoSettings.get();
  
  // This lets the CSS "bleed through" into the Shadow DOM of this element.
  bool get applyAuthorStyles => true;
  bool get preventDispose => true;
  
  ScreenModule.created() : super.created();
  
  /*
   * Run This on start on which screen
   */
  void runStartStuff() {}
  
  /*
   * Store the root router and return the mountFn
   */
  mount(String path, Router router) {
    this.path = path;
    this.router = router;
    return setupRoutes;
  }

  /*
   * Setup routes is @overrrided in which screen
   */
  void setupRoutes(Route route);

  /*
   * Navigate between screens
   */
  navigate(event, detail, target) {
     router.go("${target.dataset["target"]}", {});
  }

  /*
   * Go Home
   */
  goHome() {
    router.go("home", {});
  }

  /*
   * Go Root
   */
  goRoot() {
    router.go(path, {});
  }
  
}

/**
 * Screen abstract class
 * Used for all screen, but not for summaryDone e BigSizePhoto
 */
abstract class Screen extends ScreenModule {

  @observable bool showingData = false;
  
  void toogleShowingData(){
    if(showingData){ showingData = false; }
    else { showingData = true; }
  }
  
  void showDataInformation();
  void organizeAndDisplayData(bool showingData);
  
  Screen.created() : super.created();
  
}

/**
 * Used by SummaryDone screen and BigSizePhoto Screen
 */ 
abstract class SpecialScreen extends ScreenModule {
  
  final _Downloader = Downloader.get();
  @observable bool selection = false;
  @observable Container currentContainer;
  @observable Container summaryContainer = DB.container(SUMMARY);
  @observable Container standbyContainer = DB.container(STANDBY);
  @observable Container excludedContainer = DB.container(EXCLUDED);
  @observable bool facesCategory = false;
  @observable bool toningCategory = false;
  @observable bool sameCategory = false; 
  @observable bool dayMomentCategory = false; 
  @observable bool insideGroup = false;
  @observable bool downloading = false;
  @observable bool qualityCategory = false;
  @observable bool normalMode = true;
  AnchorElement link = new AnchorElement();
  @observable get containers => DB.containers.values;
  @observable SimilarGroupOfPhotos similarGroupOfPhotosChoosed = new SimilarGroupOfPhotos();
  @observable ColorGroupOfPhotos colorGroupOfPhotosChoosed = new ColorGroupOfPhotos();
  @observable FacesGroupOfPhotos facesGroupOfPhotosChoosed = new FacesGroupOfPhotos();
  @observable DayMomentGroupOfPhotos dayMomentGroupOfPhotosChoosed = new DayMomentGroupOfPhotos();
  @observable QualityGroupOfPhotos qualityGroupOfPhotosChoosed = new QualityGroupOfPhotos();
  @observable GroupOfPhotos lastGroupVisited = null;
  @observable Photo photo = null;
  ReceivePort receivePort = new ReceivePort();
  final List<String> selectedPhotos = toObservable([]);
  final List<Element> selectedElements = toObservable([]);
  final List<Category> selectedCategories =  toObservable([]); 
  Element _summaryContainer,
          _standByContainer,
          _excludedContainer,
          _summaryLabel,
          _standbyLabel,
          _excludedLabel,
          _summarySpan,
          _standbySpan,
          _excludedSpan;
  String screenTitle = "";
  @observable var moveToContainerFunction;
  @observable var facesCategoryExecutionFunction;
  @observable var dayMomentCategoryExecutionFunction;
  @observable var toningCategoryExecutionFunction;
  @observable var qualityCategoryExecutionFunction;
  @observable var similarCategoryExecutionFunction;
  Modal exportMenu;
  
  SpecialScreen.created() : super.created() {
    Modal.use();
    exportMenu = Modal.wire($['exportMenu']);
    _summaryContainer = $['t-SUMMARY'];
    _standByContainer = $['t-STANDBY'];
    _excludedContainer = $['t-EXCLUDED'];
    _summaryLabel = $['t-SUMMARY-label'];
    _standbyLabel = $['t-STANDBY-label'];
    _excludedLabel = $['t-EXCLUDED-label'];
    _summarySpan = $['t-SUMMARY-span'];
    _standbySpan = $['t-STANDBY-span'];
    _excludedSpan = $['t-EXCLUDED-span'];
    similarGroupOfPhotosChoosed.setGroupName("Similar");
    colorGroupOfPhotosChoosed.setGroupName("Color");
    facesGroupOfPhotosChoosed.setGroupName("With Faces");
    qualityGroupOfPhotosChoosed.setGroupName("Good Quality");
    dayMomentGroupOfPhotosChoosed.setGroupName("Day");
  }
  
  
  //bool toogleOpenExportModal() => openExportModal = !openExportModal;
  
  /*
   * Decide witch container to lock
   */ 
  void decideContainerToLock(String photoId){
    var photoContainer = DB.findContainer(photoId);
    switch(photoContainer.containerName){
      case("SUMMARY"): 
        checkSummaryContainer();
        break;
      case("STANDBY"): 
        checkStandByContainer();
        break;
      case("EXCLUDED"): 
        checkExcludedContainer();
        break;
    }
  }
    
  /*
   * 
   * Checking Containers
   * 
   */
  void removeCheckedAttribute(){
    _summaryContainer.attributes.remove('checked');
    _standByContainer.attributes.remove('checked');
    _excludedContainer.attributes.remove('checked'); 
    _summaryLabel.attributes.remove('checked');
    _standbyLabel.attributes.remove('checked');
    _excludedLabel.attributes.remove('checked');
    //_summarySpan.attributes.remove('checked');
    //_standbySpan.attributes.remove('checked');
    //_excludedSpan.attributes.remove('checked');
  }
  
  /*
   * Check destiny container
   */
  void checkDestination(String containerName){
    removeCheckedAttribute();
    switch(containerName){
      case("SUMMARY"): 
        checkSummaryContainer();
        break;
      case("STANDBY"): 
        checkStandByContainer();
        break;
      case("EXCLUDED"): 
        checkExcludedContainer();
        break;
    }
  }
  
  bool checkOverflow();
  
  /*
   * Check Summary Container
   */
  void checkSummaryContainer(){
    _summaryContainer.setAttribute("checked", "checked");
    _summaryLabel.setAttribute("checked", "checked");
    //_summarySpan.setAttribute("checked", "checked");
    currentContainer = summaryContainer;
    //cleanAll();
    checkOverflow();
  }
  
  /*
   * Check Standby Container
   */
  void checkStandByContainer(){
    _standByContainer.setAttribute("checked", "checked");
    _standbyLabel.setAttribute("checked", "checked");
    //_standbySpan.setAttribute("checked", "checked");
    currentContainer = standbyContainer;
    //cleanAll();
    checkOverflow();
  }
  
  /*
   * Check Excluded Container
   */
  void checkExcludedContainer(){
    _excludedContainer.setAttribute("checked", "checked");
    _excludedLabel.setAttribute("checked", "checked");
    //_excludedSpan.setAttribute("checked", "checked");
    currentContainer = excludedContainer;
    //cleanAll();
    checkOverflow();
  }

  void exportSummary(){
     exportMenu.show();
   }
  
  void exportToFacebook(){}
  
  void exportToHardDrive(){  
    downloading = true;
    startWorking();
  }
  
  void startWorking() {
    receivePort = new ReceivePort();

    receivePort.listen((msg){
      if (msg is SendPort){
        msg.send("Alright");
      }else{
        downloading = false;
        exportMenu.hide();
        //toogleOpenExportModal();
      }
    });
    
    //!HACK
    List aa = new List();
    aa.add(receivePort.sendPort);
    aa.add(summaryContainer);
    Isolate.spawnUri(
            _Downloader.runInIsolate(receivePort.sendPort, summaryContainer),
            [],
            receivePort.sendPort);
  }
  
  /**
   * Selection Functions
   */ 
  
  /*
   * Add to selected Photos List
   */
  void addToSelectedPhotos(String photoName){
    selectedPhotos.add(photoName);
  }

  /*
   * Remove from selected Photos List
   */
  void removeFromSelectedPhotos(String photoName){
    selectedPhotos.remove(photoName);
  }

  /*
   * Add to selected Elements list 
   */ 
  void addToSelectedElements(Element element, Element secondElement){
    selectedElements.add(element);
    selectedElements.add(secondElement);
  }

  /*
   * Remove from selected Elements list
   */ 
  void removeFromSelectedElements(Element element, Element secondElement){
    selectedElements.remove(element);
    selectedElements.remove(secondElement);
  }

  /*
   *  Return All Selected Elements
   */ 
  List<Element> returnAllSelectedElements() => selectedElements;
  
  /**
   * Location Functions
   */

  void selectContainer(event, detail, target) {
    currentContainer = DB.container(target.dataset["container"]);
    cleanSelection();
  }
  
  /**
   * Update View Functions
   * 
   */ 
  
  void updatePhotoView(Photo photo, GroupOfPhotos group){
      summaryContainer.showPhotosWithCategories(selectedCategories, photo, group, normalMode);
      standbyContainer.showPhotosWithCategories(selectedCategories, photo, group, normalMode);
      excludedContainer.showPhotosWithCategories(selectedCategories, photo, group, normalMode);
  }
  
  /*
   * Clean function
   */
  void cleanAll();
  
  void cleanCategoriesStuff(){
    cleanGroups();
    facesCategory = false;
    toningCategory = false;
    sameCategory = false; 
    dayMomentCategory = false;
    qualityCategory = false;
  }
  
  /*
   * Clean selected objects _ Used when the user cancel the selection operation
   */
  void cleanSelection(){
    var size = selectedElements.length;
    for(int i = 0; i < size; i+=2){
      selectedElements.elementAt(i).classes.remove('selectedPhoto');
      selectedElements.elementAt(i+1).classes.remove('selected');
      selectedElements.elementAt(i+1).classes.add('notSelected');
      
    }
    selectedElements.clear();
    selectedPhotos.clear();
  }
   
  /*
   * Enable Selection
   */
  bool enableSelection() => selection = true;

  /*
   * Disable Selection
   */
  void disableSelection(){
    this.selection = false;
    cleanSelection();
  }
  
  /**
   * 
   * Move Functions
   * 
   */
  
  void deleteFromAllGroups(Container destinationContainer, Photo photo){
    var remove = true,
        lists = currentContainer.allContainerGroups(),
        listsAux = new List<List<GroupOfPhotos>>(),
        groupsToDelete = new List<GroupOfPhotos>();
        
        listsAux.addAll(lists.toList());
        print("Teste 1C- Caso normal de move. Foto: " + photo.id.toString() + " a iniciar o processo.");
        List<GroupOfPhotos> groups = new List<GroupOfPhotos>();
        listsAux.forEach((groupsX){
      groups.clear();
      groups.addAll(groupsX.toList());
      groups.forEach((group){
              //Se for cara do grupo
              print("Teste 1C - Group: " + group.groupName.toString() + " with this number of ele: " 
                  + group.giveMeAllPhotos.length.toString());
              if(group.groupFace != null){ //Retirar isto quando comecar a calcular fotos dia ou noite TODO
                print("Group face: " + group.groupFace.id.toString());
                if(group.groupFace.id == photo.id){
                  print("Teste 1C1- Caso normal de move. E cara deste grupo: " + group.groupName.toString());
                  remove = false;
                  //Se tiver mais fotos no grupo
                  if(group.giveMeAllPhotos.length > 1){
                    print("Teste 1C2- Caso normal de move. Existem mais fotos no grupo. Nao vou apagar");
                    group.removeFromList(photo);
                    photo.removeGroup(group);
                    group.chooseAnotherFace();
                    print("New Face");
                  //Se nao tiver mais fotos apagar o grupo
                  }else{
                    print("Teste 1C3- Caso normal de move. Não existem mais fotos no grupo. Vou apagar o grupo");
                    groupsToDelete.add(group);
                    photo.removeGroup(group);
                  }
                  destinationContainer.tryToEnterInAGroupOrCreateANewOne(group, photo);
                }
              }
              
            //Apagar grupos que houver para apagar
            if(groupsToDelete.length > 0){
              print("Teste 1D- Caso normal de move. Apagar o grupo que fiquei de apagar");
              currentContainer.removeGroupFromList(groupsToDelete.first);
              groupsToDelete.clear();
              if(insideGroup){
                insideGroup = false;
                updatePhotoView(null, lastGroupVisited);
              }
            }
  
            if(remove){
              print("Estou a vir com a variavel remove");
              if(group.giveMeAllPhotos.contains(photo)){
                print("REMOVENDO!");
                currentContainer.removePhotoFromGroups(photo, group);
                destinationContainer.tryToEnterInAGroupOrCreateANewOne(group, photo);
              }
            }
            remove = true;
       });
    });
  }
  
  /*
   * Move to container
   */
  void moveToContainer(event, detail, target){
    var container = DB.container(target.attributes['container']),
        photos = selectedPhotos.map((id) => currentContainer.find(id)),
        photoCopy = new List<Photo>(),
        groupsToDelete = new List<SimilarGroupOfPhotos>();
    photoCopy.addAll(photos);
    
    if(isAnyCategoryOn()){
      //Se estivermos a ver os grupos e quisermos fazer move a um grupo inteiro
      if(allGroupsAreNull()){
        photos = new List<Photo>();
        if(photo != null && !normalMode){sameCategory = false;}
        photoCopy.forEach((groupFaceSelected){
          photos.addAll(groupFaceSelected.returnTheCorrectGroup(sameCategory, 
                                                                toningCategory, 
                                                                facesCategory,  
                                                                dayMomentCategory, qualityCategory).giveMeAllPhotos);
        });
        photoCopy.clear();
        if(photo != null && !normalMode){
          sameCategory = true;
          var similarPhotosOfDisplayedOne = photo.similarPhotos;
          photos.forEach((specialPhoto){
           if(similarPhotosOfDisplayedOne.contains(specialPhoto)){photoCopy.add(specialPhoto);} 
          });
        }else{photoCopy.addAll(photos);}
      }
      //por cada foto do grupo
      photoCopy.forEach((selectedPhoto){
        deleteFromAllGroups(container, selectedPhoto);
      });
      DB.moveFromTo(currentContainer.name, container.name, photoCopy);
      container.showPhotosWithCategories(selectedCategories, photo, lastGroupVisited, normalMode);
      checkDestination(container.name);
    }else{
      photoCopy.forEach((selectedPhoto){
        deleteFromAllGroups(container, selectedPhoto);
      }); 
      print("Teste 1A- Caso normal de move. As fotos já foram movidas para o container de destino");
      DB.moveFromTo(currentContainer.name, container.name, photos);
      checkDestination(container.name); 
      print("Teste 1B- Caso normal de move. para cada foto que foi movida, remover dos grupos do actual container");
      container.showPhotosWithCategories(selectedCategories, photo, new GroupOfPhotos(), normalMode);
    }
    
    disableSelection();
  }

  void showImage(Event event, var detail, Element target);
  
  /**
   * 
   * Groups
   * 
   */
  
  void getOutOfGroup(){
    cleanGroups();
    updatePhotoView(null, lastGroupVisited);
  }
  
  void cleanGroups(){
    similarGroupOfPhotosChoosed.clear();
    facesGroupOfPhotosChoosed.clear();
    colorGroupOfPhotosChoosed.clear();
    dayMomentGroupOfPhotosChoosed.clear();
    qualityGroupOfPhotosChoosed.clear();
    insideGroup = false;
  }
  
  bool allGroupsAreNull();
  bool isAnyCategoryOn();
  
  GroupOfPhotos giveMeTheRightGroupLookingToBools(bool imOnLastScreen){
     GroupOfPhotos groupToReturn = null;
     if(facesCategory){ groupToReturn = facesGroupOfPhotosChoosed; }
     if(dayMomentCategory){ groupToReturn = dayMomentGroupOfPhotosChoosed; }
     if(toningCategory){ groupToReturn = colorGroupOfPhotosChoosed; }
     if(qualityCategory){ groupToReturn = qualityGroupOfPhotosChoosed; }
     if(!imOnLastScreen){
       if(sameCategory){ groupToReturn = similarGroupOfPhotosChoosed; }
     }
     return groupToReturn;
   }
   
  bool groupFaceComparation(Photo photo, Photo secondPhoto) => photo == secondPhoto;
    
  List<GroupOfPhotos> giveMeAllGroups(){
    var groups = new List<GroupOfPhotos>();
    groups.add(facesGroupOfPhotosChoosed);
    groups.add(dayMomentGroupOfPhotosChoosed);
    groups.add(colorGroupOfPhotosChoosed);
    groups.add(qualityGroupOfPhotosChoosed);
    groups.add(similarGroupOfPhotosChoosed);
    return groups;
  }
  
  void putItToTheRightGroup(GroupOfPhotos group){
    switch(group.groupName){
      case "With Faces" : 
        facesGroupOfPhotosChoosed.addAllToList(group.giveMeAllPhotos);
        break;
      case "Without Faces" : 
        facesGroupOfPhotosChoosed.addAllToList(group.giveMeAllPhotos);
        break;
      case "Night" : 
        dayMomentGroupOfPhotosChoosed.addAllToList(group.giveMeAllPhotos);
        break;
      case "Day" : 
        dayMomentGroupOfPhotosChoosed.addAllToList(group.giveMeAllPhotos);
        break;
      case "Color": 
        colorGroupOfPhotosChoosed.addAllToList(group.giveMeAllPhotos);
        break;
      case "Black and White" : 
        colorGroupOfPhotosChoosed.addAllToList(group.giveMeAllPhotos);
        break;
      case "Good Quality" : 
        qualityGroupOfPhotosChoosed.addAllToList(group.giveMeAllPhotos);
        break;
      case "Medium Quality" : 
        qualityGroupOfPhotosChoosed.addAllToList(group.giveMeAllPhotos);
        break;
      case "Bad Quality" : 
        qualityGroupOfPhotosChoosed.addAllToList(group.giveMeAllPhotos);
        break;
      case "Similar" : 
        similarGroupOfPhotosChoosed.addAllToList(group.giveMeAllPhotos);
        break;
      default: break;
    }
  }
  
  /**
   * All Categories
   */ 
  
  void addAllCategoriesToInactive(){
    removeFromActiveCategory(faces.FacesCategory.get());
    removeFromActiveCategory(toning.ToningCategory.get());
    removeFromActiveCategory(quality.QualityCategory.get()); 
    removeFromActiveCategory(dayMoment.DayMomentCategory.get()); 
    removeFromActiveCategory(similar.SimilarCategory.get()); 
  }
  
  void addActiveCategory(Category category) => selectedCategories.add(category); 
  bool removeFromActiveCategory(Category category) => selectedCategories.remove(category);
  void clearSelectedCategories() => selectedCategories.clear();
  
  void facesCategoryExecution();
  void dayMomentCategoryExecution();
  void toningCategoryExecution();
  void qualityCategoryExecution();
  void similarCategoryExecution();
  
  void enableFacesCategory(); 
  void disableFacesCategory();
  void photosWithFacesCategory(Photo photo){
    cleanGroups();
    disableSelection();
    if(facesCategory){
      disableFacesCategory();
      //removeFromActiveCategory(faces.FacesCategory.get());
    }else{
      enableFacesCategory();
      addActiveCategory(faces.FacesCategory.get());
    }
    lastGroupVisited = facesGroupOfPhotosChoosed;
    updatePhotoView(photo, facesGroupOfPhotosChoosed);
  }
  
  void enableColorCategory();
  void disableColorCategory(); 
  void photosWithToningCategory(Photo photo){
    cleanGroups();
    disableSelection();
    if(toningCategory){
      this.disableColorCategory();
    }else{
      this.enableColorCategory();
      addActiveCategory(toning.ToningCategory.get());
    }
    lastGroupVisited = colorGroupOfPhotosChoosed;
    updatePhotoView(photo, colorGroupOfPhotosChoosed);
  }
  
  void enableSameCategory();
  void disableSameCategory();
  void photosWithSameCategory(Photo photo){
    cleanGroups();
    disableSelection();
    if(sameCategory){
      disableSameCategory();
    }else{
      enableSameCategory();
      addActiveCategory(similar.SimilarCategory.get());
    }
    lastGroupVisited = similarGroupOfPhotosChoosed;
    updatePhotoView(photo, similarGroupOfPhotosChoosed);
  }
  
  void enableDayMomentCategory();
  void disableDayMomentCategory();
  
  void photosWithDayMomentCategory(Photo photo){
    cleanGroups();
    disableSelection();
    if(dayMomentCategory){
      disableDayMomentCategory();
    }else{
      enableDayMomentCategory();
      addActiveCategory(dayMoment.DayMomentCategory.get());
    }
    lastGroupVisited = dayMomentGroupOfPhotosChoosed;
    updatePhotoView(photo, dayMomentGroupOfPhotosChoosed);
  }
  
  void enableQualityCategory();
  void disableQualityCategory();
  
  void photosWithQualityCategory(Photo photo){
    cleanGroups();
    disableSelection();
    if(qualityCategory){
      disableQualityCategory();
    }else{
      enableQualityCategory();
      addActiveCategory(quality.QualityCategory.get());
    }
    lastGroupVisited = qualityGroupOfPhotosChoosed;
    updatePhotoView(photo, qualityGroupOfPhotosChoosed);
  }
}