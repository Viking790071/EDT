
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.Property("WindowOpeningMode") Then
		WindowOpeningMode = Parameters.WindowOpeningMode
	EndIf;
	
	Parameters.Property("ChoiceMode", ChoiceMode);
	Items.Classifier.ChoiceMode = ChoiceMode;
	
	CloseOnChoice = ChoiceMode;
	
	// Service attributes
	ClassifierFields = "Code, Description, DescriptionFull, CodeAlpha2, CodeAlpha3, EEUMember";
	
	Meta = Metadata.Catalogs.WorldCountries;
	ClassifierObjectPresentation = Meta.ExtendedObjectPresentation;
	If IsBlankString(ClassifierObjectPresentation) Then
		ClassifierObjectPresentation = Meta.ObjectPresentation;
	EndIf;
	If IsBlankString(ClassifierObjectPresentation) Then
		ClassifierObjectPresentation = Meta.Presentation();
	EndIf;
	If Not IsBlankString(ClassifierObjectPresentation) Then
		ClassifierObjectPresentation = " (" + ClassifierObjectPresentation + ")";
	EndIf;
	
	ClassifierData = ClassifierState();
	Classifier.Load(ClassifierData);
	
	Filter = Classifier.FindRows(New Structure("Code", Parameters.CurrentRow.Code));
	If Filter.Count()>0 Then
		Items.Classifier.CurrentRow = Filter[0].GetID();
	EndIf;
	
	Items.ClassifierContextMenuChange.Visible = AccessRight("Update", Metadata.Catalogs.WorldCountries);
	
	HasRightToEditCountries = AccessRight("Update", Metadata.Catalogs.WorldCountries);
	Items.ClassifierContextMenuChange.Visible = HasRightToEditCountries;
	Items.ClassifierChange.Visible = HasRightToEditCountries;
	Items.Classifier.ReadOnly = NOT HasRightToEditCountries;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
		Items.Move(Items.ClassifierChange, Items.CommandBarForm);
		Items.Move(Items.ClassifierGroupOutputList, Items.CommandBarForm);
		Items.Move(Items.ClassifierGroupSearch, Items.CommandBarForm);
		Items.Move(Items.ClassifierSortListAsc, Items.CommandBarForm);
		Items.Move(Items.ClassifierSortListDesc, Items.CommandBarForm);
		Items.Move(Items.ClassifierHelp, Items.CommandBarForm);
		
		Items.ClassifierGroupOutputList.Type = FormGroupType.ButtonGroup;
		Items.ClassifierGroupSearch.Type = FormGroupType.ButtonGroup;
		Items.Classifier.CommandBarLocation = FormItemCommandBarLabelLocation.None;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ClassifierFormTableItemsEventHandlers

&AtClient
Procedure ClassifierChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	
	If RowSelected = Undefined Or Not HasRightToEditCountries Then
		Return;
	EndIf;

	If Not ChoiceMode Then
		Country = Classifier.FindByID(RowSelected);
		
		If NoCountryInCountriesList(Country.Description) Then
			QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Добавить страну ""%1"" из классификатора в список стран мира?'; en = 'Add country ""%1"" from the classifier to the list of countries of the world?'; pl = 'Dodać kraj ""%1"" z klasyfikatora do listy państw świata?';es_ES = '¿Añadir el país ""%1"" del clasificador a la lista de los países del mundo?';es_CO = '¿Añadir el país ""%1"" del clasificador a la lista de los países del mundo?';tr = 'Dünya ülkeleri listesine sınıflandırıcıdan ""%1"" ülke ekle?';it = 'Aggiungere paese ""%1"" dal classificatore all''elenco dei paesi del mondo?';de = 'Ein Land ""%1"" aus dem Klassifikator zur Liste der Länder der Welt hinzufügen?'"),
				Country.Description);
			Notification = New NotifyDescription("AddCountry", ThisObject, RowSelected);
			ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo);
		EndIf;
	Else
		If TypeOf(RowSelected) = Type("Array") Then
			SelectionRowID = RowSelected[0];
		Else
			SelectionRowID = RowSelected;
		EndIf;
		
		NotifyClassifierItemChoice(SelectionRowID);
	EndIf;
EndProcedure

&AtClient
Procedure AddCountry(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		NotifyClassifierItemChoice(AdditionalParameters);
	EndIf;

EndProcedure

&AtClient
Procedure ClassifierValueChoice(Item, Value, StandardProcessing)
	NotifyClassifierItemChoice(Value);
EndProcedure

&AtClient
Procedure ClassifierBeforeRowChange(Item, Cancel)
	Cancel = True;
	If HasRightToEditCountries Then
		OpenClassifierItemForm(Items.Classifier.CurrentData);
	EndIf;
EndProcedure

&AtClient
Procedure ClassifierBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	Cancel = True;
EndProcedure

&AtClient
Procedure ClassifierBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure OpenClassifierItemForm(FillingData, IsNew = False)
	If FillingData=Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Basis", New Structure(ClassifierFields));
	FillPropertyValues(FormParameters.Basis, FillingData);
	If IsNew Then
		FormParameters.Basis.Insert("Code", "--");
	Else
		FormParameters.Insert("ReadOnly", True);
	EndIf;
	Form = OpenForm("Catalog.WorldCountries.ObjectForm", FormParameters, Items.Classifier);
	If Not IsNew AND Form.AutoTitle Then 
		Form.AutoTitle = False;
		Form.Title = FillingData.Description + ClassifierObjectPresentation;
	EndIf;
EndProcedure

&AtClient
Procedure NotifyClassifierItemChoice(SelectionRowID)
	AllRowData = Classifier.FindByID(SelectionRowID);
	If AllRowData <> Undefined Then
		RowData = New Structure(ClassifierFields);
		FillPropertyValues(RowData, AllRowData);
		
		ChoiceData = ClassifierItemChoiceData(RowData);
		If ChoiceData.IsNew Then
			NotifyOfItemCreation(ChoiceData.Ref);
		EndIf;
		
		NotifyChoice(ChoiceData.Ref);
	EndIf;
EndProcedure

&AtClient
Procedure NotifyOfItemCreation(Ref)
	NotifyWritingNew(Ref);
	Notify("Catalog.WorldCountries.Update", Ref, ThisObject);
EndProcedure

&AtServerNoContext
Function ClassifierItemChoiceData(Val CountryData)
	// Searching by code only because all codes are specified in the classifier.
	Ref = Catalogs.WorldCountries.FindByCode(CountryData.Code);
	IsNew = Not ValueIsFilled(Ref);
	If IsNew Then
		Country = Catalogs.WorldCountries.CreateItem();
		FillPropertyValues(Country, CountryData);
		Country.Write();
		Ref = Country.Ref;
	EndIf;
	
	Return New Structure("Ref, IsNew, Code", Ref, IsNew, CountryData.Code);
EndFunction

&AtServerNoContext
Function ClassifierState()
	Data = ContactsManager.ClassifierTable();
	
	Data.Columns.Add("IconIndex", New TypeDescription("Number", New NumberQualifiers(2, 0)));
	Data.FillValues(8, "IconIndex");
	
	Query = New Query("SELECT Code FROM Catalog.WorldCountries WHERE Predefined");
	For Each RowOfPredefined In Query.Execute().Unload() Do
		DataString = Data.Find(RowOfPredefined.Code, "Code");
		If DataString<>Undefined Then
			DataString.IconIndex = 5;
		EndIf;
	EndDo;
	
	Return Data;
EndFunction

&AtServerNoContext
Function NoCountryInCountriesList(Country)
	
	Query = New Query;
	Query.Text = 
		"SELECT WorldCountries.Ref
		|FROM Catalog.WorldCountries AS WorldCountries
		|WHERE WorldCountries.Description = &Description";
	
	Query.SetParameter("Description", Country);
	QueryResult = Query.Execute().Select();
	
	If QueryResult.Next() Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion
