#Region FormEventHandlers

&AtServer 
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	For Each Row In Metadata.DocumentJournals.SubcontractingDocumentsForServicesProvided.RegisteredDocuments Do
		Items.DocumentType.ChoiceList.Add(Row.Synonym, Row.Synonym);
		DocumentTypes.Add(Row.Synonym, Row.Name);
	EndDo;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Company						= Settings.Get("Company");
	DocumentTypePresentation	= Settings.Get("DocumentTypePresentation");
	Counterparty				= Settings.Get("Counterparty");
	
	SelectedTypeOfDocument = DocumentTypes.FindByValue(DocumentTypePresentation);
	If SelectedTypeOfDocument = Undefined Then
		DocumentType = "";
	Else
		DocumentType = SelectedTypeOfDocument.Presentation;
	EndIf;
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	DriveClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	DriveClientServer.SetListFilterItem(List,
		"Type",
		?(ValueIsFilled(DocumentType), Type("DocumentRef." + DocumentType), Undefined),
		ValueIsFilled(DocumentType));
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DocumentTypeOnChange(Item)
	
	SelectedTypeOfDocument = DocumentTypes.FindByValue(DocumentTypePresentation);
	If SelectedTypeOfDocument = Undefined Then
		DocumentType = "";
	Else
		DocumentType = SelectedTypeOfDocument.Presentation;
	EndIf;
	
	DriveClientServer.SetListFilterItem(List,
		"Type",
		?(ValueIsFilled(DocumentType), Type("DocumentRef." + DocumentType), Undefined),
		ValueIsFilled(DocumentType));
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure ListBeforeAddRow1(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	If ValueIsFilled(DocumentType) Then
		
		Cancel = True;
		
		ParametersStructure = New Structure();
		ParametersStructure.Insert("Counterparty", Counterparty);
		ParametersStructure.Insert("Company", Company);
		
		OpenForm("Document." + DocumentType + ".ObjectForm", New Structure("FillingValues", ParametersStructure));
		
	EndIf;
	
EndProcedure

#EndRegion