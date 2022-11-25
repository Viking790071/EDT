#Region Variables

&AtServer
Var SubordinationItems;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	DefineSettings();
	
	Parameters.Property("FilterObject", ObjectRef);
	InitialObject = ObjectRef;
	If ValueIsFilled(ObjectRef) Then
		UpdateSubordinationStructureTree();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Update(Command)
	
	OutputSubordinationStructure();
	
EndProcedure

&AtClient
Procedure OutputForCurrent(Command)
	
	CurrentObject = Items.ReportTable.CurrentArea.Details;
	
	If ValueIsFilled(CurrentObject) Then
		ObjectRef = CurrentObject;
	Else
		Return;
	EndIf;
	
	OutputSubordinationStructure();
	
EndProcedure

#EndRegion

#Region Private

//////////////////////////////////////////////////////////////////////////////////////////////
// Procedures for output to the spreadsheet document.

// Outputs subordination tree to the spreadsheet document.
&AtServer
Procedure OutputSpreadsheetDocument()

	ReportTable.Clear();
	
	Template = GetCommonTemplate("SubordinationStructure");
	
	OutputParentTreeItems(TreeParentObjects.GetItems(),Template,1);
	OutputCurrentObject(Template);
	OutputSubordinateTreeItems(TreeSubordinateObjects.GetItems(),Template,1)
	
EndProcedure

// Outputs parent object tree rows.
//
// Parameters:
//  TreeRows - FormDataTreeItemCollection - tree rows to be output to the spreadsheet document.
//                 
//  Template - SpreadsheetDocumentTemplate - template used as basis for output to the spreadsheet 
//           document.
//  RecursionLevel - Number - procedure recursion level.
//
&AtServer
Procedure OutputParentTreeItems(TreeRows,Template,RecursionLevel)
	
	Counter =  TreeRows.Count();
	While Counter >0 Do
		
		CurrentTreeRow = TreeRows.Get(Counter -1);
		SubordinateItemsTreeRows = CurrentTreeRow.GetItems();
		OutputParentTreeItems(SubordinateItemsTreeRows,Template,RecursionLevel + 1);
		
		For ind=1 To RecursionLevel Do
			
			If ind = RecursionLevel Then
				
				If TreeRows.IndexOf(CurrentTreeRow) < (TreeRows.Count()-1) Then
					Area = Template.GetArea("ConnectorTopRightBottom");
				Else	
					Area = Template.GetArea("ConnectorRightBottom");
				EndIf;
				
			Else
				
				If VerticalConnectorOutput(RecursionLevel - ind + 1,CurrentTreeRow,False) Then
					Area = Template.GetArea("ConnectorTopBottom");
				Else
					Area = Template.GetArea("Indent");
					
				EndIf;
				
			EndIf;
			
			If ind = 1 Then
				ReportTable.Put(Area);
			Else
				ReportTable.Join(Area);
			EndIf;
			
		EndDo;
		
		OutputPresentationAndPicture(CurrentTreeRow,Template,False,False);

		Counter = Counter - 1;
		
	EndDo;
	
EndProcedure

// Outputs the picture to the spreadsheet document that matches object status and its presentation.
//
&AtServer
Procedure OutputPresentationAndPicture(TreeRow,Template, IsCurrentObject = False, IsSubordinateItem = Undefined)
	
	ObjectMetadata = TreeRow.Ref.Metadata();
	IsDocument       = Common.IsDocument(ObjectMetadata);
	
	// Picture output type
	If TreeRow.Posted Then
		If IsCurrentObject Then
			If TreeSubordinateObjects.GetItems().Count() AND TreeParentObjects.GetItems().Count()  Then
				PictureArea = Template.GetArea("DocumentPostedConnectorTopBottom");
			ElsIf TreeSubordinateObjects.GetItems().Count() Then
				PictureArea = Template.GetArea("DocumentPostedConnectorBottom");
			Else
				PictureArea = Template.GetArea("DocumentPostedConnectorTop");
			EndIf;
		ElsIf IsSubordinateItem = True Then
			If TreeRow.GetItems().Count() Then
				PictureArea = Template.GetArea("DocumentPostedConnectorLeftBottom");
			Else
				PictureArea = Template.GetArea("DocumentPosted");
			EndIf;
		Else
			If TreeRow.GetItems().Count() Then
				PictureArea = Template.GetArea("DocumentPostedConnectorLeftTop");
			Else
				PictureArea = Template.GetArea("DocumentPosted");
			EndIf;
		EndIf;
	ElsIf TreeRow.DeletionMark Then
		If IsCurrentObject Then
			If TreeSubordinateObjects.GetItems().Count() AND TreeParentObjects.GetItems().Count()  Then
				AreaName = ?( IsDocument, "DocumentMarkedForDeletionConnectorTopBottom", "CatalogCCTMarkedForDeletionConnectorTopBottom");
				PictureArea = Template.GetArea(AreaName);
			ElsIf TreeSubordinateObjects.GetItems().Count() Then
				AreaName = ?( IsDocument, "DocumentMarkedForDeletionConnectorBottom", "CatalogCCTMarkedForDeletionConnectorBottom");
				PictureArea = Template.GetArea(AreaName);
			Else
				AreaName = ?( IsDocument, "DocumentMarkedForDeletionConnectorTop", "CatalogCCTMarkedForDeletionConnectorTop");
				PictureArea = Template.GetArea(AreaName);
			EndIf;
		ElsIf IsSubordinateItem = True Then
			If TreeRow.GetItems().Count() Then
				AreaName = ?( IsDocument, "DocumentMarkedForDeletionConnectorLeftBottom", "CatalogCCTMarkedForDeletionConnectorLeftBottom");
				PictureArea = Template.GetArea(AreaName);
			Else
				AreaName = ?( IsDocument, "DocumentMarkedForDeletion", "CatalogCCTMarkedForDeletionConnectorLeft");
				PictureArea = Template.GetArea(AreaName);
			EndIf;
		Else
			If TreeRow.GetItems().Count() Then
				AreaName = ?( IsDocument, "DocumentMarkedForDeletionConnectorLeftTop", "CatalogCCTMarkedForDeletionConnectorLeftTop");
				PictureArea = Template.GetArea(AreaName);
			Else
				AreaName = ?( IsDocument, "DocumentMarkedForDeletion", "CatalogCCTMarkedForDeletionConnectorLeft");
				PictureArea = Template.GetArea(AreaName);
			EndIf;
		EndIf;
	Else
		If IsCurrentObject Then
			If TreeSubordinateObjects.GetItems().Count() AND TreeParentObjects.GetItems().Count()  Then
				AreaName = ?( IsDocument, "DocumentWrittenConnectorTopBottom", "CatalogCCTConnectorTopBottom");
				PictureArea = Template.GetArea(AreaName);
			ElsIf TreeSubordinateObjects.GetItems().Count() Then
				AreaName = ?( IsDocument, "DocumentWrittenConnectorDown", "CatalogCCTConnectorBottom");
				PictureArea = Template.GetArea(AreaName);
			Else
				AreaName = ?( IsDocument, "DocumentWrittenConnectorTop", "CatalogCCTConnectorTop");
				PictureArea = Template.GetArea(AreaName);
			EndIf;
		ElsIf IsSubordinateItem = True Then
			If TreeRow.GetItems().Count() Then
				AreaName = ?( IsDocument, "DocumentWrittenConnectorLeftBottom", "CatalogCCTConnectorLeftBottom");
				PictureArea = Template.GetArea(AreaName);
			Else
				AreaName = ?( IsDocument, "DocumentWritten", "CatalogCCTConnectorLeft");
				PictureArea = Template.GetArea(AreaName);
			EndIf;
		Else
			If TreeRow.GetItems().Count() Then
				AreaName = ?( IsDocument, "DocumentWrittenConnectorLeftTop", "CatalogCCTConnectorLeftTop");
				PictureArea = Template.GetArea(AreaName);
			Else
				AreaName = ?( IsDocument, "DocumentWritten", "CatalogCCTConnectorLeft");
				PictureArea = Template.GetArea(AreaName);
			EndIf;
		EndIf;
	EndIf;
	If IsCurrentObject Then
		ReportTable.Put(PictureArea) 
	Else
		ReportTable.Join(PictureArea);
	EndIf;
	
	// Object output
	ObjectArea = Template.GetArea(?(IsCurrentObject,"CurrentObject","Object"));
	ObjectArea.Parameters.ObjectPresentation = TreeRow.Presentation;
	ObjectArea.Parameters.Object = TreeRow.Ref;
	ReportTable.Join(ObjectArea);
	
EndProcedure

// Specifies whether output the vertical connector to the spreadsheet document is required.
//
// Parameters:
//  LevelUp - Number - how many levels higher is the parent from which the vertical connector will 
//                 be drawn.
//  TreeRow - FormDataTreeItem - original value tree row from which counting is started.
//                  
// Returns:
//   Boolean - specifies whether output to the vertical connector areas is required.
//
&AtServer
Function VerticalConnectorOutput(LevelUp,TreeRow,SearchAmongSubordinates = True)
	
	CurrentRow = TreeRow;
	
	For ind=1 To LevelUp Do
		
		CurrentRow = CurrentRow.GetParent();
		If ind = LevelUp Then
			SearchParent = CurrentRow;
		ElsIf ind = (LevelUp-1) Then
			SearchRow = CurrentRow;
		EndIf;
		
	EndDo;
	
	If SearchParent = Undefined Then
		If SearchAmongSubordinates Then
			SubordinateParentItems =  TreeSubordinateObjects.GetItems(); 
		Else
			SubordinateParentItems =  TreeParentObjects.GetItems();
		EndIf;
	Else
		SubordinateParentItems =  SearchParent.GetItems(); 
	EndIf;
	
	Return SubordinateParentItems.IndexOf(SearchRow) < (SubordinateParentItems.Count()-1);
	
EndFunction

// Outputs the row with the document, for which the subordination structure is generated to the spreadsheet document.
//
// Parameters:
//  Template - SpreadsheetDocumentTemplate - template used as basis for spreadsheet document.
&AtServer
Procedure OutputCurrentObject(Template)
	
	Selection = GetSelectionByObjectAttributes(ObjectRef);
	If Selection.Next() Then
		
		OverridablePresentation = ObjectPresentationForOutput(Selection);
		If OverridablePresentation <> Undefined Then
			AttributesStructure = Common.ValueTableRowToStructure(Selection.Owner().Unload()[0]);
			AttributesStructure.Presentation = OverridablePresentation;
			OutputPresentationAndPicture(AttributesStructure, Template, True);
		Else
			AttributesStructure = Common.ValueTableRowToStructure(Selection.Owner().Unload()[0]);
			AttributesStructure.Presentation = ObjectPresentationForReportOutput(Selection);
			OutputPresentationAndPicture(AttributesStructure, Template, True);
		EndIf;
		
	EndIf;
	
EndProcedure

// Generates document presentation for output to the spreadsheet document.
//
// Parameters:
//  Selection - QueryResultSelection or FormDataTreeItem - data set used as basis for presentation 
//             generation.
//
// Returns:
//   String - generated presentation.
//
&AtServer
Function ObjectPresentationForReportOutput(Selection)
	
	ObjectPresentation = Selection.Presentation;
	ObjectMetadata = Selection.Ref.Metadata();
	
	If Common.IsDocument(ObjectMetadata) Then
		If (Selection.DocumentAmount <> 0) AND (Selection.DocumentAmount <> NULL) Then
			ObjectPresentation = ObjectPresentation + " " + NStr("ru='на сумму'; en = 'in the amount of'; pl = 'na sumę';es_ES = 'al importe de';es_CO = 'al importe de';tr = 'tutarında';it = 'Nell''importo di';de = 'in Höhe von'") + " " + Selection.DocumentAmount + " " + Selection.Currency;
		EndIf;
	Else
		ObjectPresentation = ObjectPresentation + " (" + ObjectMetadata.ObjectPresentation + ")";
	EndIf;
	
	Return ObjectPresentation;
	
EndFunction

// Outputs subordinate document tree rows.
//
// Parameters:
//  TreeRows - FormDataTreeItemCollection - tree rows to be output to the spreadsheet document.
//                 
//  Template - SpreadsheetDocumentTemplate - template used as basis for output to the spreadsheet 
//                 document.
//  RecursionLevel - Number - procedure recursion level.
//
&AtServer
Procedure OutputSubordinateTreeItems(TreeRows,Template,RecursionLevel)

	For each TreeRow In TreeRows Do
		
		IsCurrentObject = (TreeRow.Ref = ObjectRef);
		IsInitialObject = (TreeRow.Ref = InitialObject);
		SubordinateTreeItems = TreeRow.GetItems();
		
		// Connectors output
		For ind = 1 To RecursionLevel Do
			If RecursionLevel > ind Then
				
				If VerticalConnectorOutput(RecursionLevel - ind + 1,TreeRow) Then
					Area = Template.GetArea("ConnectorTopBottom");
				Else
					Area = Template.GetArea("Indent");
					
				EndIf;
			Else 
				
				If TreeRows.Count() > 1 AND (TreeRows.IndexOf(TreeRow)<> (TreeRows.Count()-1)) Then
					Area = Template.GetArea("ConnectorTopRightBottom");
				Else
					Area = Template.GetArea("ConnectorTopRight");
				EndIf;
				
			EndIf;	
			
			Area.Parameters.Document = ?(IsInitialObject,Undefined,TreeRow.Ref);
			
			If ind = 1 Then
				ReportTable.Put(Area);
			Else
				ReportTable.Join(Area);
			EndIf;
			
		EndDo;		
		
		OutputPresentationAndPicture(TreeRow,Template,False,True);
		
		// Output of subordinate tree items.
		OutputSubordinateTreeItems(SubordinateTreeItems,Template,RecursionLevel + 1);
		
	EndDo;
	
EndProcedure

// Initiates output to the spreadsheet document and displays it at the end of generation.
&AtClient
Procedure OutputSubordinationStructure()

	UpdateSubordinationStructureTree();

EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////
// Procedures for creating document subordination tree.

&AtServer
Procedure UpdateSubordinationStructureTree()

	If MainDocumentIsAvailable() Then
		GenerateDocumentTrees();
		OutputSpreadsheetDocument();
	Else
		CommonClientServer.MessageToUser(
			NStr("ru = 'Документ, для которого сформирован отчет о структуре подчиненности, стал недоступен.'; en = 'The document for which the hierarchy report is generated is no longer available.'; pl = 'Dokument, dla którego generowany jest sprawozdanie o strukturze zależności, nie jest już dostępny.';es_ES = 'El documento para el cual el informe de la estructura de dependencia está generado, no se encuentra disponible más.';es_CO = 'El documento para el cual el informe de la estructura de dependencia está generado, no se encuentra disponible más.';tr = 'Tabiiyet yapısıyla ilgili raporun oluşturulduğu belge artık erişilemiyor.';it = 'Il documento per il quale il report gerarchico è stato generato non è più disponibile.';de = 'Das Dokument, für das der Abhängigkeitsstrukturbericht generiert wird, ist nicht mehr verfügbar.'"));
	EndIf;

EndProcedure

&AtServer
Procedure GenerateDocumentTrees()
	
	SubordinationItems = New Array;
	
	TreeParentObjects.GetItems().Clear();
	TreeSubordinateObjects.GetItems().Clear();
	
	OutputParentObjects(ObjectRef, TreeParentObjects);
	OutputSubordinateObjects(ObjectRef, TreeSubordinateObjects);
	
EndProcedure

&AtServer
Function MainDocumentIsAvailable()

	Query = New Query(
	"SELECT ALLOWED
	|	1
	|FROM
	|	" + ObjectRef.Metadata().FullName() + " AS Tab
	|WHERE
	|	Tab.Ref = &CurrentObject
	|");
	Query.SetParameter("CurrentObject", ObjectRef);
	Return Not Query.Execute().IsEmpty();

EndFunction

// Gets selection by object attributes.
//
// Parameters:
//  ObjectRef - DocumentRef, CatalogRef, CCTRef - reference to the object the attribute values of 
//                                                                which are received with query.
//
// Returns:
//   QueryResultSelection
//
&AtServer
Function GetSelectionByObjectAttributes(ObjectRef)
	
	ObjectMetadata = ObjectRef.Metadata();
	
	QueryText = 
	"SELECT ALLOWED
	|	Ref,
	|	#Posted,
	|	DeletionMark,
	|	#Amount ,
	|	#Currency,
	|	#Presentation
	|FROM
	|	" + ObjectMetadata.FullName() + "
	|WHERE
	|	Ref = &Ref
	|";
	
	If Common.IsDocument(ObjectMetadata) Then
		AttributeNameAmount    = DocumentAttributeName(ObjectMetadata, "DocumentAmount");
		AttributeNameCurrency   = DocumentAttributeName(ObjectMetadata, "Currency");
		If ObjectMetadata.Posting = Metadata.ObjectProperties.Posting.Allow Then
			AttributeNamePosted = "Posted";
		Else
			AttributeNamePosted = "NOT DeletionMark";
		EndIf;
	Else
		AttributeNameAmount    = Undefined;
		AttributeNameCurrency   = Undefined;
		AttributeNamePosted = "False";
	EndIf;
	
	ReplaceQueryText(QueryText, ObjectMetadata, "#Posted", AttributeNamePosted, "Posted", True);
	ReplaceQueryText(QueryText, ObjectMetadata, "#Amount", AttributeNameAmount, "DocumentAmount");
	ReplaceQueryText(QueryText, ObjectMetadata, "#Currency", AttributeNameCurrency, "Currency");
	
	AdditionalAttributesArray = AttributesForPresentation(ObjectMetadata.FullName(), ObjectMetadata.Name);
	SupplementQueryTextByObjectAttributes(QueryText, AdditionalAttributesArray);
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", ObjectRef);
	Return Query.Execute().Select(); 
	
EndFunction

&AtServer
Procedure OutputParentObjects(CurrentObject, ParentTree)

	TreeRows = ParentTree.GetItems();
	ObjectMetadata = CurrentObject.Metadata();
	AttributesList    = New ValueList;
	
	For Each Attribute In ObjectMetadata.Attributes Do
		
		If Not Metadata.FilterCriteria.RelatedDocuments.Content.Contains(Attribute) Then
			Continue;
		EndIf;
		
		For Each CurrentType In Attribute.Type.Types() Do
			
			AttributeMetadata = Metadata.FindByType(CurrentType);
			If AttributeMetadata = Undefined Then
				Continue;
			EndIf;
			If Not Common.MetadataObjectAvailableByFunctionalOptions(AttributeMetadata) 
				Or Not AccessRight("Read", AttributeMetadata) Then
				Continue;
			EndIf;
			If Not Metadata.Documents.Contains(AttributeMetadata)
				AND Not Metadata.Catalogs.Contains(AttributeMetadata)
				AND Not Metadata.ChartsOfCharacteristicTypes.Contains(AttributeMetadata) Then
				Continue;
			EndIf;
				
			AttributeValue = CurrentObject[Attribute.Name];
			If ValueIsFilled(AttributeValue)
				AND TypeOf(AttributeValue) = CurrentType
				AND AttributeValue <> CurrentObject
				AND AttributesList.FindByValue(AttributeValue) = Undefined Then
				
				IsADocument  = Common.IsDocument(AttributeMetadata);
				
				If IsADocument Then
					AttributesList.Add(AttributeValue,
						Format(Common.ObjectAttributeValue(AttributeValue, "Date", True), "DLF=DT"));
				Else
					AttributesList.Add(AttributeValue, Date(1,1,1));
				EndIf;
				
			EndIf;
		EndDo;
		
	EndDo;

	For Each TS In ObjectMetadata.TabularSections Do
		
		AttributesNames = "";
		TSContent = CurrentObject[TS.Name].Unload();
		For Each Attribute In TS.Attributes Do

			If Not Metadata.FilterCriteria.RelatedDocuments.Content.Contains(Attribute) Then
				Continue;
			EndIf;
				
			For Each CurrentType In Attribute.Type.Types() Do
				
				AttributeMetadata = Metadata.FindByType(CurrentType);
				If AttributeMetadata = Undefined Then
					Continue;
				EndIf;
				If Not Common.MetadataObjectAvailableByFunctionalOptions(AttributeMetadata) 
					Or Not AccessRight("Read", AttributeMetadata) Then
					Continue;
				EndIf;
				
				If Not Metadata.Documents.Contains(AttributeMetadata)
					AND Not Metadata.Catalogs.Contains(AttributeMetadata)
					AND Not Metadata.ChartsOfCharacteristicTypes.Contains(AttributeMetadata) Then
					Continue;
				EndIf;
				
				AttributesNames = AttributesNames + ?(AttributesNames = "", "", ", ") + Attribute.Name;
				Break;
					
			EndDo;
			
		EndDo;

		TSContent.GroupBy(AttributesNames);
		For Each TSColumn In TSContent.Columns Do

			For Each TSRow In TSContent Do

				AttributeValue = TSRow[TSColumn.Name];
				ValueMetadata = Metadata.FindByType(TypeOf(AttributeValue));
				If ValueMetadata = Undefined Then
					Continue;
				EndIf;
				If Not Common.MetadataObjectAvailableByFunctionalOptions(ValueMetadata) 
					Or Not AccessRight("Read", ValueMetadata) Then
					Continue;
				EndIf;
				If AttributeValue = CurrentObject
					Or AttributesList.FindByValue(AttributeValue) <> Undefined Then
					Continue;
				EndIf;
				
				IsADocument  = Common.IsDocument(ValueMetadata);
				If Not IsADocument AND Not Metadata.Catalogs.Contains(ValueMetadata)
					AND Not Metadata.ChartsOfCharacteristicTypes.Contains(ValueMetadata) Then
					Continue;
				EndIf;
				
				If IsADocument Then
					AttributesList.Add(AttributeValue,
						Format(Common.ObjectAttributeValue(AttributeValue, "Date", True), "DLF=DT"));
				Else
					AttributesList.Add(AttributeValue, Date(1,1,1));
				EndIf;
				
			EndDo;
		EndDo;
	EndDo;

	AttributesList.SortByPresentation();
	
	For each ListItem In AttributesList Do
		
		Selection = GetSelectionByObjectAttributes(ListItem.Value);
		
		If Selection.Next() Then
			TreeRow = AddRowToTree(TreeRows, Selection);
			If NOT AddedObjectIsAmongParents(ParentTree, ListItem.Value) Then
				OutputParentObjects(ListItem.Value, TreeRow);
			EndIf;
		EndIf;
		
	EndDo;
	
EndProcedure

// Determines whether the document is among the parents of the tree row that can be added.
//
// Parameters:
//  ParentRow - FormDataTree, FormDataTreeItem - the parent for which tree row can be added.
//                 
//  SearchObject - Reference - reference to the metadata object that is being checked for.
//
// Returns:
//   Boolean - true if the object is found, false otherwise.
//
&AtServer
Function AddedObjectIsAmongParents(ParentRow, SearchObject)
	
	If SearchObject = ObjectRef Then
		Return True;
	EndIf;
	
	If TypeOf(ParentRow) = Type("FormDataTree") Then
		Return False; 
	EndIf;
	
	CurrentParent = ParentRow;
	While CurrentParent <> Undefined Do
		If CurrentParent.Ref = SearchObject Then
		    Return True;
		EndIf;
		CurrentParent = CurrentParent.GetParent();
	EndDo;
	
	Return False;
	
EndFunction

&AtServer
Function AlreadyWasDisplayed(SearchObject)
	
	If SubordinationItems.Find(SearchObject) <> Undefined Then
		Return True;
	EndIf;
	
	SubordinationItems.Add(SearchObject);
	
	Return False;
	
EndFunction

&AtServer
Procedure ReplaceQueryText(QueryText, ObjectMetadata, WhatToReplace, AttributeName, Presentation, DoNotSearchInAttributes = False)

	If DoNotSearchInAttributes Or ObjectMetadata.Attributes.Find(AttributeName) <> Undefined Then
		QueryText = StrReplace(QueryText, WhatToReplace, AttributeName + " AS " + Presentation);
	Else
		QueryText = StrReplace(QueryText, WhatToReplace, " NULL AS " + Presentation);
	EndIf;

EndProcedure

&AtServer
Procedure SupplementMetadataCache(ObjectMetadata, ObjectName, ObjectAttributeCache)

	DocumentAttributes = ObjectAttributeCache[ObjectName];
	If DocumentAttributes = Undefined Then
		
		DocumentAttributes = New Map;
		IsADocument = Common.IsDocument(ObjectMetadata);
		
		If IsADocument Then 
			
			AttributeNameDocumentAmount = DocumentAttributeName(ObjectMetadata, "DocumentAmount");
			
			If ObjectMetadata.Attributes.Find(AttributeNameDocumentAmount) <> Undefined Then
				DocumentAttributes.Insert("DocumentAmount", AttributeNameDocumentAmount);
			Else
				DocumentAttributes.Insert("DocumentAmount", "NULL");
			EndIf;
			
		Else
			
			DocumentAttributes.Insert("DocumentAmount", "NULL");
			
		EndIf;
		
		If IsADocument Then
			
			AttributeNameCurrency = DocumentAttributeName(ObjectMetadata, "Currency");
			
			If ObjectMetadata.Attributes.Find(AttributeNameCurrency) <> Undefined Then
				DocumentAttributes.Insert("Currency", AttributeNameCurrency);
			Else
				DocumentAttributes.Insert("Currency", "NULL");
			EndIf;
			
		Else
			
			DocumentAttributes.Insert("Currency", "NULL");
			
		EndIf;
		
		If IsADocument Then
			
			AttributeNameCompany = DocumentAttributeName(ObjectMetadata, "Company");
			
			If ObjectMetadata.Attributes.Find(AttributeNameCompany) <> Undefined Then
				DocumentAttributes.Insert("Company", AttributeNameCompany);
			Else
				DocumentAttributes.Insert("Company", "NULL");
			EndIf;
			
		Else
			
			DocumentAttributes.Insert("Company", "NULL");
			
		EndIf;
		
		If IsADocument Then
			DocumentAttributes.Insert("Posted", "Posted");
		Else
			DocumentAttributes.Insert("Posted", "False");
		EndIf;
		
		If IsADocument Then
			DocumentAttributes.Insert("Date", "Date");
		Else
			DocumentAttributes.Insert("Date", "NULL");
		EndIf;
		
		ObjectAttributeCache.Insert(ObjectName, DocumentAttributes);
		
	EndIf;
	
EndProcedure

&AtServer
Function ObjectsByFilterCriteria(FilterCriteriaValue)
	
	If Not Metadata.FilterCriteria.RelatedDocuments.Type.ContainsType(TypeOf(FilterCriteriaValue))  Then
		Return Undefined;
	EndIf;
		
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "SELECT
	|	RelatedDocuments.Ref
	|FROM
	|	FilterCriterion.RelatedDocuments(&FilterCriteriaValue) AS RelatedDocuments";
	
	Query.SetParameter("FilterCriteriaValue", FilterCriteriaValue);
	Return Query.Execute().Unload();
	
EndFunction

&AtServer
Procedure OutputSubordinateObjects(CurrentObject, ParentTree)
	
	TreeRows = ParentTree.GetItems();
	Table      = ObjectsByFilterCriteria(CurrentObject);
	If Table = Undefined Then
		Return;
	EndIf;

	CacheByObjectType   = New Map;
	ObjectAttributeCache = New Map;

	For Each TableRow In Table Do

		ObjectMetadata = TableRow.Ref.Metadata();
		If Not AccessRight("Read", ObjectMetadata) Then
			Continue;
		EndIf;

		FullObjectName = ObjectMetadata.FullName();
		SupplementMetadataCache(ObjectMetadata, FullObjectName, ObjectAttributeCache);

		RefsArray = CacheByObjectType[FullObjectName];
		If RefsArray = Undefined Then

			RefsArray = New Array;
			CacheByObjectType.Insert(FullObjectName, RefsArray);

		EndIf;

		RefsArray.Add(TableRow.Ref);

	EndDo;
	
	If CacheByObjectType.Count() = 0 Then
		Return;
	EndIf;

	QueryTextBegin = "SELECT ALLOWED * FROM (";
	QueryTextEnd = ") AS SubordinateObjects ORDER BY SubordinateObjects.Date";

	Query = New Query;
	QueryText = "";
	For Each KeyAndValue In CacheByObjectType Do
		
		ObjectNameArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(KeyAndValue.Key, ".");
		If ObjectNameArray.Count() = 2 Then
			ObjectName = ObjectNameArray[1];
		Else
			Continue;
		EndIf;

		TextByObjectType = "
		|" + ObjectAttributeCache[KeyAndValue.Key]["Date"] + "           AS Date,
		|	Ref,
		|" + ObjectAttributeCache[KeyAndValue.Key]["Posted"] + "       AS Posted,
		|	DeletionMark,
		|" + ObjectAttributeCache[KeyAndValue.Key]["DocumentAmount"] + " AS DocumentAmount,
		|" + ObjectAttributeCache[KeyAndValue.Key]["Currency"] + "         AS Currency,
		|" + ObjectAttributeCache[KeyAndValue.Key]["Company"] + "         AS Company,
		|	#Presentation
		|FROM
		|	" + KeyAndValue.Key + "
		|WHERE
		|	Ref IN (&" + ObjectName + ")";
		
		Query.SetParameter(ObjectName, KeyAndValue.Value);
		
		AdditionalAttributesArray = AttributesForPresentation(KeyAndValue.Key, ObjectName);
		SupplementQueryTextByObjectAttributes(TextByObjectType, AdditionalAttributesArray);
		
		QueryText = QueryText + ?(QueryText = "", " SELECT ", " UNION ALL SELECT ") + TextByObjectType;

	EndDo;

	Query.Text = QueryTextBegin + QueryText + QueryTextEnd;
	Selection = Query.Execute().Select();

	While Selection.Next() Do
		
		If AlreadyWasDisplayed(Selection.Ref) Then
			Continue;
		EndIf;
		
		NewRow = AddRowToTree(TreeRows, Selection);
		If Not AddedObjectIsAmongParents(ParentTree, Selection.Ref) Then
			OutputSubordinateObjects(Selection.Ref, NewRow)
		EndIf;
		
	EndDo;

EndProcedure

&AtServer
Function AddRowToTree(TreeRows, Selection)

	NewRow = TreeRows.Add();
	FillPropertyValues(NewRow, Selection, "Ref, Presentation, DocumentAmount, Currency, Posted, DeletionMark");
	
	OverridablePresentation = ObjectPresentationForOutput(Selection);
	If OverridablePresentation <> Undefined Then
		NewRow.Presentation = OverridablePresentation;
	Else
		NewRow.Presentation = ObjectPresentationForReportOutput(Selection);
	EndIf;
	
	Return NewRow;

EndFunction

&AtServer
Procedure SupplementQueryTextByObjectAttributes(QueryText, AttributesArray)
	
	TextPresentation = "Presentation AS Presentation";
	
	For Ind = 1 To 3 Do
		
		TextPresentation = TextPresentation + ",
			|	" + ?(AttributesArray.Count() >= Ind,AttributesArray[Ind - 1],"NULL") + " AS AdditionalAttribute" + Ind;
		
	EndDo;
	
	QueryText = StrReplace(QueryText, "#Presentation", TextPresentation);
	
EndProcedure

&AtServer
Function DocumentAttributeName(Val ObjectMetadata, Val AttributeName) 
	
	AttributesNames = Settings.Attributes[ObjectMetadata.FullName()];
	If AttributesNames <> Undefined Then
		Result = AttributesNames[AttributeName];
		Return ?(Result <> Undefined, Result, AttributeName);
	EndIf;	
	
	// For backward compatibility.
	DocumentAttributeName = DependenciesOverridable.DocumentAttributeName(ObjectMetadata.Name, AttributeName); 
	If AttributeName = "DocumentAmount" Then
		Return ?(DocumentAttributeName = Undefined, "DocumentAmount", DocumentAttributeName);
	ElsIf AttributeName = "Currency" Then
		Return ?(DocumentAttributeName = Undefined, "Currency", DocumentAttributeName);
	ElsIf AttributeName = "Company" Then
		Return ?(DocumentAttributeName = Undefined, "Company", DocumentAttributeName);
	EndIf;
	
EndFunction

&AtServer
Procedure DefineSettings()
	
	SubsystemSettings = New Structure;
	SubsystemSettings.Insert("Attributes", New Map);
	SubsystemSettings.Insert("AttributesForPresentation", New Map);
	DependenciesOverridable.OnDefineSettings(SubsystemSettings);
	
	Settings = SubsystemSettings;

EndProcedure

&AtServer
Function AttributesForPresentation(Val FullMetadataObjectName, Val MetadataObjectName)
	
	Result = Settings.AttributesForPresentation[FullMetadataObjectName];
	If Result <> Undefined Then
		Return Result;
	EndIf;
	
	// For backward compatibility.
	Return DependenciesOverridable.ObjectAttributesArrayForPresentationGeneration(MetadataObjectName);

EndFunction

&AtServer
Function ObjectPresentationForOutput(Data) 
	
	Result = "";
	StandardProcessing = True;	
	DependenciesOverridable.OnGettingPresentation(TypeOf(Data.Ref), Data, Result, StandardProcessing);
	If Not StandardProcessing Then
		Return Result;
	EndIf;
	
	// For backward compatibility.
	Return DependenciesOverridable.ObjectPresentationForReportOutput(Data);
	
EndFunction
	
#EndRegion
