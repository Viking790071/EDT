
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	FormNameDocumentTypesContentSetting = DataProcessorObject.Metadata().FullName()
		+ ".Form.DocumentsKindsCompositionSetting";
	
	SetSettingsKey();
	
	FillQueryTable(DataProcessorObject);
	
	UpdateDocumentTypesList();
	
	RestoreSettings();
	
	UpdateQueryText();
	
	ApplyCommandParameters();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	SaveSettings();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersDocumentsTable

&AtClient
Procedure DocumentsTableSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ShowValue(Undefined, Item.CurrentData.Document);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SetContentOfDocuments(Command)
	
	EditContentOfDocuments();
	
EndProcedure

&AtClient
Procedure Generate(Command)
	
	UpdateDocumentsTableAtServer();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure UpdateQueryText()
	
	TempQueryText = "";
	For Each TabRow In RequestsTable.FindRows(New Structure("Use", True)) Do
		
		TempQueryText = TempQueryText + ?(IsBlankString(TempQueryText), "", " UNION ALL ") + TabRow.QueryText;
		
	EndDo;
	
	Position = Find(UPPER(TempQueryText), Upper("Select"));
	If Position > 0 Then
		
		TempQueryText = "SELECT ALLOWED " + Mid(TempQueryText, Position + StrLen("SELECT")) + 
		"ORDER
		|	BY
		|	Date, Document
		|";
		
	EndIf;
	
	QueryTextByDocuments = TempQueryText;
	
EndProcedure

&AtServer
Procedure SetFlagOfDocumentKindUsage()
	
	For Each Row In RequestsTable Do
		
		ListItem = DocumentsKindsList.FindByValue(Row.DocumentName);
		If ListItem <> Undefined Then
			Row.Use = ListItem.Check;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure UpdateDocumentTypesList()
	
	DocumentsKindsList.Clear();
	
	For Each Row In RequestsTable Do
		DocumentsKindsList.Add(Row.DocumentName, Row.DocumentSynonym, Row.Use);
	EndDo;
	
	DocumentsKindsList.SortByPresentation(SortDirection.Asc);
	
EndProcedure

&AtServer
Procedure ApplySettingsToDocumentTypesList(SettingValue)
	
	RearrangeQuery = False;
	
	For Each Item In SettingValue Do
		
		ItemOfList = DocumentsKindsList.FindByValue(Item.Value);
		If ItemOfList <> Undefined And ItemOfList.Check <> Item.Check Then
			
			ItemOfList.Check = Item.Check;
			RearrangeQuery = True;
			
		EndIf;
		
	EndDo;
	
	If RearrangeQuery Then
		
		SetFlagOfDocumentKindUsage();
		
		UpdateQueryText();
		
		SaveSettings();
		
		UpdateDocumentsTableAtServer();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EditContentOfDocuments()
	
	NotifyDescription = New NotifyDescription("EditContentOfDocumentsEnd", ThisObject);
	
	OpenForm(FormNameDocumentTypesContentSetting,
		New Structure("DocumentsKindsList", DocumentsKindsList),,,,,
		NotifyDescription);
	
EndProcedure

&AtClient
Procedure EditContentOfDocumentsEnd(Result,Parameters) Export
	
	If TypeOf(Result) = Type("ValueList") Then
		ApplySettingsToDocumentTypesList(Result);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateDocumentsTableAtServer()
	
	If IsBlankString(QueryTextByDocuments) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'It is necessary to set content of documents'; ru = 'Необходимо настроить состав документов';pl = 'Należy ustawić zawartość dokumentów';es_ES = 'Es necesario establecer el contenido de documentos';es_CO = 'Es necesario establecer el contenido de documentos';tr = 'Belgelerin içeriğini ayarlamak gerekir';it = 'È necessario impostare il contenuto dei documenti';de = 'Es ist nötig den Inhalt der Dokumente einzustellen'"));
		Return;
		
	EndIf;
	
	Query = New Query(QueryTextByDocuments);
	Query.SetParameter("Parameter", Parameter);
	
	DocumentsTableTemp = Query.Execute().Unload();
	
	For Each TempTableRow In DocumentsTableTemp Do
		If Not ValueIsFilled(TempTableRow.DocumentAmount) Then
			TempTableRow.DocumentCurrency = "";
		EndIf;
	EndDo;
	
	ValueToFormAttribute(DocumentsTableTemp, "DocumentsTable");
	
EndProcedure

&AtServer
Procedure ApplyCommandParameters()
	
	If Parameters.Property("Filter") Then
		
		CommonClientServer.SetFormItemProperty(Items, "Parameter", "Visible", False);
		Parameters.Filter.Property("Project", Parameter);
		
	EndIf;
	
	If Parameters.Property("GenerateOnOpen") And Parameters.GenerateOnOpen Then
		
		UpdateDocumentsTableAtServer();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillQueryTable(DataProcessorObject)
	
	HeaderFields = New Array;
	HeaderFields.Add("DocumentAmount");
	HeaderFields.Add("OperationKind");
	HeaderFields.Add("DocumentCurrency");
	HeaderFields.Add("Company");
	HeaderFields.Add("Responsible");
	HeaderFields.Add("Comment");
	HeaderFields.Add("Author");
	
	DataProcessorObject.FillQueryTable(RequestsTable, HeaderFields, , "ProjectDocuments");
	
EndProcedure

#Region Settings

&AtServer
Procedure RestoreSettings()
	
	SettingsValue = CommonSettingsStorage.Load("DataProcessor.CounterpartyDocuments", SettingsKey);
	
	If TypeOf(SettingsValue) = Type("Map") Then
		
		ValueFromSetting = SettingsValue.Get("DocumentsKindsList");
		If TypeOf(ValueFromSetting) = Type("ValueList") Then
			ApplySettingsToDocumentTypesList(ValueFromSetting);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SaveSettings()
	
	Settings = New Map;
	Settings.Insert("DocumentsKindsList", DocumentsKindsList);
	
	CommonSettingsStorage.Save("DataProcessor.CounterpartyDocuments", SettingsKey, Settings);
	
EndProcedure

&AtServer
Procedure SetSettingsKey()
	
	If Parameters.Property("SettingsKey") And Not IsBlankString(Parameters.SettingsKey) Then
		
		SettingsKey = Parameters.SettingsKey;
		
	Else
		
		SettingsKey = "WithoutProject";
		
	EndIf;
	
	SettingsKey = SettingsKey + "_" + Users.CurrentUser().UUID();
	
	If Parameters.Property("Filter") And Parameters.Filter.Property("Project") Then
		
		SettingsKey = SettingsKey + "_" + Parameters.Filter.Project.UUID();
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
