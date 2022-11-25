
#Region EventHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Initializing internal flags.
	CanAddToCatalog = ContactsManagerInternal.HasRightToAdd();
	
	If Parameters.AllowClassifierData=Undefined Then
		AllowClassifierData = True;
	Else
		BooleanType = New TypeDescription("Boolean");
		AllowClassifierData = BooleanType.AdjustValue(Parameters.AllowClassifierData);
	EndIf;
	
	OnlyClassifierData = Parameters.OnlyClassifierData;
	Parameters.Property("ChoiceMode", ChoiceMode);
	
	// Allowing items
	Items.List.ChoiceMode = ChoiceMode;
	CommonClientServer.SetFormItemProperty(Items, "ListSelect", "DefaultButton", ChoiceMode);
	Items.Create.Visible  = CanAddToCatalog;
	
	// Determining a mode according to flags
	If ChoiceMode Then
		If AllowClassifierData Then
			If OnlyClassifierData Then
				If CanAddToCatalog Then 
					// Selecting only countries listed in the classifier.
					OpenClassifierForm = True
					
				Else
					// Showing only items present both in the catalog and in the classifier.
					SetCatalogAndClassifierIntersectionFilter();
					// Hiding classifier buttons.
					Items.ListSelectFromClassifier.Visible = False;
					Items.ListClassifier.Visible           = False;
				EndIf;
				
			Else
				If CanAddToCatalog Then 
					// Showing classifier and classifier selection button. These are the default settings.
				Else
					// Hiding classifier buttons.
					Items.ListSelectFromClassifier.Visible = False;
					Items.ListClassifier.Visible           = False;
				EndIf;
			EndIf;
			
		 Else
			// Showing catalog items only.
			Items.ListClassifier.Visible = False;
			// Hiding classifier buttons.
			Items.ListSelectFromClassifier.Visible = False;
			Items.ListClassifier.Visible           = False;
		EndIf;
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
		For each FormItem In Items.ListCommandBar.ChildItems Do
			
			Items.Move(FormItem, Items.CommandBarForm);
			
		EndDo;
		
		Items.Move(Items.ListClassifier, Items.CommandBarForm);
		Items.Move(Items.ListSelectFromClassifier, Items.AddMobileClientGroup);
		Items.Move(Items.ListCreate, Items.AddMobileClientGroup);
		
		CommonClientServer.SetFormItemProperty(Items, "ListCreate", "Title", NStr("ru ='Новый...'; en = 'New...'; pl = 'Nowy...';es_ES = 'Nuevo...';es_CO = 'Nuevo...';tr = 'Yeni...';it = 'Nuovo...';de = 'Neue...'"));
		CommonClientServer.SetFormItemProperty(Items, "ListCreate", "OnlyInAllActions", False);
		CommonClientServer.SetFormItemProperty(Items, "ListCreate", "Picture", PictureLib.Empty);
		CommonClientServer.SetFormItemProperty(Items, "ListSelectFromClassifier", "Title", NStr("ru ='Из классификатора'; en = 'From classifier'; pl = 'Z klasyfikatora';es_ES = 'Del clasificador';es_CO = 'Del clasificador';tr = 'Sınıflandırıcıdan';it = 'Da classificatore';de = 'Aus dem Klassifikator'"));
		CommonClientServer.SetFormItemProperty(Items, "ListSelectFromClassifier", "Picture", PictureLib.Empty);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If OpenClassifierForm Then
		// Selecting only countries listed in the classifier; opening classifier form for selection.
		OpeningParameters = New Structure;
		OpeningParameters.Insert("ChoiceMode",        True);
		OpeningParameters.Insert("CloseOnChoice", CloseOnChoice);
		OpeningParameters.Insert("CurrentRow",      Items.List.CurrentRow);
		OpeningParameters.Insert("WindowOpeningMode",  WindowOpeningMode);
		OpeningParameters.Insert("CurrentRow",      Items.List.CurrentRow);
		
		OpenForm("Catalog.WorldCountries.Form.Classifier", OpeningParameters, FormOwner);
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName="Catalog.WorldCountries.Update" Then
		RefreshCountriesListDisplay();
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ChoiceProcessingList(Item, ValueSelected, StandardProcessing)
	If ChoiceMode Then
		// Selecting from classifier.
		NotifyChoice(ValueSelected);
	EndIf;
EndProcedure

&AtClient
Procedure NewObjectWriteProcessingList(Item, NewObject, Source)
	RefreshCountriesListDisplay();
EndProcedure

#EndRegion

#Region FormCommandHandlers
//

&AtClient
Procedure OpenClassifier(Command)
	// Opening for viewing
	OpeningParameters = New Structure;
	OpeningParameters.Insert("CurrentRow", Items.List.CurrentRow);
	OpenForm("Catalog.WorldCountries.Form.Classifier", OpeningParameters, Items.List);
EndProcedure

&AtClient
Procedure SelectFromClassifier(Command)
	
	// Opening for selection
	OpeningParameters = New Structure;
	OpeningParameters.Insert("ChoiceMode", True);
	OpeningParameters.Insert("CloseOnChoice", CloseOnChoice);
	OpeningParameters.Insert("CurrentRow", Items.List.CurrentRow);
	OpeningParameters.Insert("WindowOpeningMode", WindowOpeningMode);
	OpeningParameters.Insert("CurrentRow", Items.List.CurrentRow);
	OpenForm("Catalog.WorldCountries.Form.Classifier", OpeningParameters, Items.List,,,,, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region Private
//

&AtClient
Procedure RefreshCountriesListDisplay()
	
	If RefFilterItemID<>Undefined Then
		// An additional filter is set and it is to be updated.
		SetCatalogAndClassifierIntersectionFilter();
	EndIf;
	
	Items.List.Refresh();
EndProcedure

&AtServer
Procedure SetCatalogAndClassifierIntersectionFilter()
	ListFilter = List.SettingsComposer.FixedSettings.Filter;
	
	If RefFilterItemID=Undefined Then
		FilterItem = ListFilter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		FilterItem.LeftValue    = New DataCompositionField("Ref");
		FilterItem.ComparisonType     = DataCompositionComparisonType.InList;
		FilterItem.Use    = True;
		
		RefFilterItemID = ListFilter.GetIDByObject(FilterItem);
	Else
		FilterItem = ListFilter.GetObjectByID(RefFilterItemID);
	EndIf;
	
	Query = New Query("
		|SELECT
		|	Code, Description
		|INTO
		|	Classifier
		|FROM
		|	&Classifier AS Classifier
		|INDEX BY
		|	Code, Description
		|;////////////////////////////////////////////////////////////
		|SELECT 
		|	Ref
		|FROM
		|	Catalog.WorldCountries AS WorldCountries
		|INNER JOIN
		|	Classifier AS Classifier
		|ON
		|	WorldCountries.Code = Classifier.Code
		|	AND WorldCountries.Description = Classifier.Description
		|");
	Query.SetParameter("Classifier", ContactsManager.ClassifierTable());
	FilterItem.RightValue = Query.Execute().Unload().UnloadColumn("Ref");
EndProcedure

#EndRegion
