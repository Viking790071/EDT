
#Region Public

Function EDIParameters() Export
	
	ParametersOnCreateAtServer = New Structure("
		|Form,
		|Ref,
		|StateDecoration,
		|StateGroup,
		|SpotForCommands");
	
	Return ParametersOnCreateAtServer;
	
EndFunction

Procedure OnCreateAtServer_DocumentForm(Parameters) Export
	
	EDIProfile = EDIProfileForDocument(Parameters.Ref);
	
	If ValueIsFilled(EDIProfile) Then
		
		EDIState = GetEDIState(Parameters.Ref);
		Parameters.Insert("EDIState", EDIState);
		FillEDIState(Parameters);
		
		If EDIState.StatusRef <> Undefined
			And Common.ObjectAttributeValue(EDIState.StatusRef, "IsFinal") <> True Then
			PostCommandsToForm(Parameters.Form, Parameters.SpotForCommands);
		EndIf;
		
	Else
		
		Parameters.StateGroup.Visible = False;
		
	EndIf;
	
EndProcedure

Procedure AfterWriteAtServer_DocumentForm(DocumentObject, Parameters) Export
	
	EDIProfile = EDIProfileForDocument(Parameters.Ref);
	
	If ValueIsFilled(EDIProfile) Then
		
		WriteEDIState(Parameters.Ref, EDIProfile);
		
		EDIState = GetEDIState(Parameters.Ref);
		Parameters.Insert("EDIState", EDIState);
		FillEDIState(Parameters);
		
		If Common.ObjectAttributeValue(EDIState.StatusRef, "IsFinal") <> True Then
			PostCommandsToForm(Parameters.Form, Parameters.SpotForCommands);
		EndIf;
		
		Parameters.StateGroup.Visible = True;
		
	Else
		
		Parameters.StateGroup.Visible = False;
		
	EndIf;
	
EndProcedure

Procedure OnWrite_ObjectModule(DocumentRef, Cancel) Export
	
	If Constants.ProhibitEDocumentsChanging.Get() Then
		
		If DocumentWasSent(DocumentRef) Then
			
			CommonClientServer.MessageToUser(
			NStr("en = 'Document has already been sent to EDI system. It is prohibited to change documents after sending.'; ru = 'Документ уже был отправлен в систему электронного документооборота. Изменение документов после отправки запрещено.';pl = 'Dokument został już wysłany do systemu elektronicznej wymiany dokumentów. Zabroniona jest zmiana dokumentów po wysłaniu.';es_ES = 'El documento ya ha sido enviado al sistema EDI. Está prohibido modificar los documentos después de su envío.';es_CO = 'El documento ya ha sido enviado al sistema EDI. Está prohibido modificar los documentos después de su envío.';tr = 'Belge EDI sistemine gönderildi. Belgeler gönderimden sonra değiştirilemez.';it = 'Il documento è già stato inviato al sistema EDI. Non è consentita la modifica dei documenti dopo il loro invio.';de = 'Dokument wurde bereits an das EDI-System gesendet. Es ist verboten, Dokumente nach dem Senden zu ändern.'"),
			,
			,
			,
			Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure EDICommands(EDICommands) Export
	
	EDICommand = EDICommands.Add();
	EDICommand.Handler = "EDIServer.SendDocument";
	EDICommand.FormsList = "";
	EDICommand.ID = "SendInvoice";
	EDICommand.Presentation = NStr("en = 'Submit'; ru = 'Отправить';pl = 'Prześlij';es_ES = 'Presentar';es_CO = 'Presentar';tr = 'Gönder';it = 'Presentare';de = 'Einreichen'");
	EDICommand.Order = 10;
	EDICommand.Picture = PictureLib.OpenFile;
	EDICommand.ParameterUseMode = CommandParameterUseMode.Single;
	EDICommand.PlacementSpot = "EDICommands";
	EDICommand.Representation = ButtonRepresentation.PictureAndText;
	EDICommand.Disabled = False;
	
	EDICommand = EDICommands.Add();
	EDICommand.Handler = "EDIServer.GetInvoiceStatus";
	EDICommand.FormsList = "";
	EDICommand.ID = "GetInvoiceStatus";
	EDICommand.Presentation = NStr("en = 'Refresh status'; ru = 'Обновить статус';pl = 'Odśwież status';es_ES = 'Actualizar el estado';es_CO = 'Actualizar el estado';tr = 'Durumu yenile';it = 'Aggiornare stato';de = 'Status aktualisieren'");
	EDICommand.Order = 11;
	EDICommand.Picture = PictureLib.Refresh;
	EDICommand.ParameterUseMode = CommandParameterUseMode.Single;
	EDICommand.PlacementSpot = "EDICommands";
	EDICommand.Representation = ButtonRepresentation.PictureAndText;
	EDICommand.Disabled = False;
	
	EDICommand = EDICommands.Add();
	EDICommand.Handler = "EDIServer.CancelInvoice";
	EDICommand.FormsList = "";
	EDICommand.ID = "CancelInvoice";
	EDICommand.Presentation = NStr("en = 'Revoke'; ru = 'Отозвать';pl = 'Zabroń';es_ES = 'Revocar';es_CO = 'Revocar';tr = 'Reddet';it = 'Revocare';de = 'Aufheben'");
	EDICommand.Order = 12;
	EDICommand.Picture = PictureLib.Delete;
	EDICommand.ParameterUseMode = CommandParameterUseMode.Single;
	EDICommand.PlacementSpot = "EDICommands";
	EDICommand.Representation = ButtonRepresentation.PictureAndText;
	EDICommand.Disabled = False;
	
EndProcedure

Procedure CheckConnection(EDIProfile, HasErrors) Export
	
	EDIAttributes = Common.ObjectAttributesValues(EDIProfile, "Ref, Provider, Company, CompanyTaxNumber, CompanyEmail, UserName");
	
	
	
EndProcedure

Procedure GetInvoiceStatus(Parameters, ResultAddress) Export
	
	ResultStructure = ResultStructure();
	ExecuteGetInvoiceStatus(Parameters.DocumentsArray, ResultStructure);
	PutToTempStorage(ResultStructure, ResultAddress);
	
EndProcedure

Procedure CancelInvoice(Parameters, ResultAddress) Export
	
	ResultStructure = ResultStructure();
	ExecuteCancelInvoice(Parameters.DocumentsArray, ResultStructure);
	PutToTempStorage(ResultStructure, ResultAddress);
	
EndProcedure

Procedure SendDocument(Parameters, ResultAddress) Export
	
	ResultStructure = ResultStructure();
	ExecuteSendDocument(Parameters.DocumentsArray, ResultStructure);
	PutToTempStorage(ResultStructure, ResultAddress);

EndProcedure

Procedure PostCommandsToForm(Form, DefaultPlacementSpot, OnlyInAllActions = False) Export
	
	If DefaultPlacementSpot = Undefined Then
		PlacementSpot = Form.CommandBar;
		Submenu = Form.Items.Add(PlacementSpot.Name + "EDICommands", Type("FormGroup"), PlacementSpot);
		Submenu.Type = FormGroupType.Popup;
		Submenu.Description = NStr("en = 'EDI'; ru = 'Электронный документооборот';pl = 'Elektroniczna wymiana dokumentów';es_ES = 'EDI';es_CO = 'EDI';tr = 'EDI';it = 'Sistema di scambio documenti (EDI)';de = 'EDI'");
		DefaultPlacementSpot = Submenu;
	EndIf;
	
	If DefaultPlacementSpot.ChildItems.Count() = 0 Then
		
		CommandsInForm = CommandsInForm();
		Commands = CommandsInForm.Copy();
		
		If DefaultPlacementSpot <> Undefined Then
			For Each Command In Commands Do
				Command.PlacementSpot = DefaultPlacementSpot.Name;
			EndDo;
		EndIf;
		
		Commands.Columns.Add("CommandNameAtForm", New TypeDescription("String"));
		
		CommandTable = Commands.Copy(, "PlacementSpot");
		CommandTable.GroupBy("PlacementSpot");
		PlacementSpots = CommandTable.UnloadColumn("PlacementSpot");
		
		For Each PlacementSpot In PlacementSpots Do
			
			Filter = New Structure("PlacementSpot, Disabled", PlacementSpot, False);
			FoundedCommands = Commands.FindRows(Filter);
			
			ItemForPlacement = Form.Items.Find(PlacementSpot);
			If ItemForPlacement = Undefined Then
				ItemForPlacement = DefaultPlacementSpot;
			EndIf;
			
			If FoundedCommands.Count() > 0 Then
				AddCommands(Form, FoundedCommands, ItemForPlacement);
			EndIf;
			
		EndDo;
		
		CommandsAddressInTempStorage = "EDICommandsAddressInTempStorage";
		FormCommand = Form.Commands.Find(CommandsAddressInTempStorage);
		If FormCommand = Undefined Then
			FormCommand = Form.Commands.Add(CommandsAddressInTempStorage);
			FormCommand.Action = PutToTempStorage(Commands, Form.UUID);
		Else
			ListOfCommonCommands = GetFromTempStorage(FormCommand.Action);
			For Each Command In Commands Do
				FillPropertyValues(ListOfCommonCommands.Add(), Command);
			EndDo;
			Command.Action = PutToTempStorage(ListOfCommonCommands, Form.UUID);
		EndIf;
		
	EndIf;
	
EndProcedure

Function GetEDIState(Ref) Export
	
	Result = New Structure("StatusRef, Status, StatusDescription");
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	EDocumentsStatusesSliceLast.Provider AS Provider,
		|	EDocumentsStatusesSliceLast.Status AS Status,
		|	EDocumentsStatusesSliceLast.StatusDescription AS StatusDescription
		|FROM
		|	InformationRegister.EDocumentsStatuses.SliceLast(, ElectronicDocument = &ElectronicDocument) AS EDocumentsStatusesSliceLast";
	
	Query.SetParameter("ElectronicDocument", Ref);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		
		ResultTemplate = "%1: %2";
		
		If ValueIsFilled(SelectionDetailRecords.Status) Then
			
			Result.StatusRef = SelectionDetailRecords.Status;			
			Result.Status = StringFunctionsClientServer.SubstituteParametersToString(
				ResultTemplate,
				SelectionDetailRecords.Provider,
				SelectionDetailRecords.Status);				
			Result.StatusDescription = SelectionDetailRecords.StatusDescription;
			
		Else
			Result.StatusRef = Catalogs.EDocumentStatuses.EmptyRef();
			Result.Status = StringFunctionsClientServer.SubstituteParametersToString(
				ResultTemplate,
				SelectionDetailRecords.Provider,
				NStr("en = 'ready for exchange'; ru = 'готов к обмену';pl = 'gotowe do wymiany';es_ES = 'listo para el intercambio';es_CO = 'listo para el intercambio';tr = 'değişim için hazır';it = 'pronto allo scambio';de = 'für Austausch bereit'"));	
			Result.StatusDescription = "";
			
		EndIf;
		
	Else
		
		Result.StatusRef = Catalogs.EDocumentStatuses.EmptyRef();
		Result.Status = NStr("en = 'not ready for exchange'; ru = 'не готов к обмену';pl = 'nie gotowe do wymiany';es_ES = 'no está listo para el intercambio';es_CO = 'no está listo para el intercambio';tr = 'değişim için hazır değil';it = 'non pronto allo scambio';de = 'für Austausch nicht bereit'");
		Result.StatusDescription = NStr("en = 'You can submit document after reposting it.'; ru = 'Вы можете отправить документ после перепроведения.';pl = 'Możesz przesłać dokument po jego zatwierdzeniu.';es_ES = 'Puede presentar el documento después de reenviarlo.';es_CO = 'Puede presentar el documento después de reenviarlo.';tr = 'Belgeyi yeniden yayınladıktan sonra gönderebilirsiniz.';it = 'È possibile presentare il documento dopo averlo ripubblicato.';de = 'Sie können das Dokument nach einer erneuten Buchung einreichen.'");
		
	EndIf;
	
	Return Result;
	
EndFunction

Function DocumentWasSent(DocumentRef) Export
	
	Result = False;
	
	If GetFunctionalOption("UseEDIExchange") Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	EDIStatuses.Status AS Status
		|FROM
		|	InformationRegister.EDocumentsStatuses.SliceLast(, ElectronicDocument = &DocumentRef) AS EDIStatuses
		|		INNER JOIN Catalog.EDocumentStatuses AS EDocumentStatuses
		|		ON EDIStatuses.Status = EDocumentStatuses.Ref
		|WHERE
		|	NOT EDocumentStatuses.IsRejected";
		
		Query.SetParameter("DocumentRef", DocumentRef);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		Result = SelectionDetailRecords.Next();
		
	EndIf;
	
	Return Result;
	
EndFunction

Function ProhibitEDocumentsChanging() Export
	
	Return Constants.ProhibitEDocumentsChanging.Get();
	
EndFunction

Function CounterpartyInfoToCheck(Counterparty) Export
	
	Result = New Structure;
	
	AttributesNames = New Array;
	AttributesNames.Add("TIN");
	AttributesNames.Add("LegalEntityIndividual");
	AttributesNames.Add("Description");
	
	
	Attributes = Common.ObjectAttributesValues(Counterparty, AttributesNames);
	
	Result.Insert("CounterpartyTIN", Attributes.TIN);
	Result.Insert("CounterpartyEmail",
		ContactsManager.ObjectContactInformation(Counterparty, Catalogs.ContactInformationKinds.CounterpartyEmail));
	Result.Insert("CounterpartyPostalAddress",
		ContactsManager.ObjectContactInformation(Counterparty, Catalogs.ContactInformationKinds.CounterpartyLegalAddress));
	Result.Insert("IsIndividual", Attributes.LegalEntityIndividual = Enums.CounterpartyType.Individual);
	Result.Insert("NameParts", StrSplit(Attributes.Description, " "));
	
	
	Return Result;

EndFunction

#EndRegion

#Region Private

Function CommandsInForm()
	
	EDICommands = EDICommandsTable();
	
	EDICommands(EDICommands);
	
	Return EDICommands;
	
EndFunction

Function EDICommandsTable()
	
	EDICommandsTable = New ValueTable;
	
	// Description
	EDICommandsTable.Columns.Add("ID", New TypeDescription("String"));
	EDICommandsTable.Columns.Add("Presentation", New TypeDescription("String"));
	
	// Options
	EDICommandsTable.Columns.Add("Handler", New TypeDescription("String"));
	
	// command presentation
	EDICommandsTable.Columns.Add("Order", New TypeDescription("Number"));
	EDICommandsTable.Columns.Add("Picture", New TypeDescription("Picture"));
	EDICommandsTable.Columns.Add("Representation", New TypeDescription("ButtonRepresentation"));
	
	// placement
	EDICommandsTable.Columns.Add("FormsList", New TypeDescription("String"));
	EDICommandsTable.Columns.Add("PlacementSpot", New TypeDescription("String"));
	EDICommandsTable.Columns.Add("ParameterUseMode", New TypeDescription("CommandParameterUseMode"));
	
	// internal
	EDICommandsTable.Columns.Add("OnlyInAllActions", New TypeDescription("Boolean"));
	EDICommandsTable.Columns.Add("Disabled", New TypeDescription("Boolean"));
	
	Return EDICommandsTable;
	
EndFunction

Procedure ExecuteGetInvoiceStatus(DocumentsArray, ResultStructure)
	
	If DocumentsArray.Count() > 0 Then
		
		// Expect documents from one provider
		EDIProfile = EDIProfileForDocument(DocumentsArray[0]);
		
		
	
	EndIf;
	
EndProcedure

Procedure ExecuteCancelInvoice(DocumentsArray, ResultStructure)
	
	If DocumentsArray.Count() > 0 Then
		
		// Expect documents from one provider
		EDIProfile = EDIProfileForDocument(DocumentsArray[0]);
		
		
	
	EndIf;
	
EndProcedure

Procedure ExecuteSendDocument(DocumentsArray, ResultStructure)
	
	If DocumentsArray.Count() > 0 Then
		
		// Expect documents from one provider
		EDIProfile = EDIProfileForDocument(DocumentsArray[0]);
		
		
	
	EndIf;

EndProcedure

Procedure WriteEDIState(DocumentRef, EDIProfile)
	
	Provider = Common.ObjectAttributeValue(EDIProfile, "Provider");
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	EDocumentsStatusesSliceLast.Status AS Status
	|FROM
	|	InformationRegister.EDocumentsStatuses.SliceLast(
	|			,
	|			Provider = &Provider
	|				AND ElectronicDocument = &DocumentRef) AS EDocumentsStatusesSliceLast";
	
	Query.SetParameter("DocumentRef", DocumentRef);
	Query.SetParameter("Provider", Provider);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		
		EmptyStateRecord = InformationRegisters.EDocumentsStatuses.CreateRecordManager();
		EmptyStateRecord.Period = CurrentSessionDate();
		EmptyStateRecord.ElectronicDocument = DocumentRef;
		EmptyStateRecord.Provider = Provider;
		EmptyStateRecord.Status = Catalogs.EDocumentStatuses.EmptyRef();
		EmptyStateRecord.Write();
		
	EndIf;
	
EndProcedure

Function EDIProfileForDocument(DocumentRef)
	
	Result = Catalogs.EDIProfiles.EmptyRef();
	
	If GetFunctionalOption("UseEDIExchange") And AccessRight("Edit", Metadata.InformationRegisters.EDocumentsStatuses) Then
		
		DocumentAttributes = Common.ObjectAttributesValues(DocumentRef, "Counterparty, Company, Posted");
		
		If DocumentAttributes.Posted = True Then
			
			CheckCounterpartyProvider = GetFunctionalOption("CheckCounterpartyProvider");
			ProviderFilter = Enums.EDIProviders.EmptyRef();
			
			If CheckCounterpartyProvider Then
				
				QueryProvider = New Query;
				QueryProvider.Text = 
				"SELECT
				|	CounterpartyProviders.Provider AS Provider
				|FROM
				|	InformationRegister.CounterpartyProviders AS CounterpartyProviders
				|WHERE
				|	CounterpartyProviders.Counterparty = &Counterparty";
				
				QueryProvider.SetParameter("Counterparty", DocumentAttributes.Counterparty);
				
				QueryResult = QueryProvider.Execute();
				
				SelectionProvider = QueryResult.Select();
				
				If SelectionProvider.Next() Then
					
					ProviderFilter = SelectionProvider.Provider;
					
				EndIf;
				
			EndIf;
			
			If Not CheckCounterpartyProvider Or ValueIsFilled(ProviderFilter) Then
				
				Query = New Query;
				Query.Text = 
				"SELECT
				|	EDIProfiles.Ref AS Ref
				|FROM
				|	Catalog.EDIProfiles.DocumentsForExchange AS EDIProfilesDocumentsForExchange
				|		INNER JOIN Catalog.EDIProfiles AS EDIProfiles
				|		ON EDIProfilesDocumentsForExchange.Ref = EDIProfiles.Ref
				|WHERE
				|	EDIProfilesDocumentsForExchange.DocumentType = &DocumentType
				|	AND EDIProfiles.Company = &Company
				|	AND &ProviderFilter
				|	AND NOT EDIProfiles.DeletionMark
				|	AND EDIProfilesDocumentsForExchange.Use";
				
				If CheckCounterpartyProvider Then
					Query.Text = StrReplace(Query.Text, "&ProviderFilter", "EDIProfiles.Provider = &Provider");
				Else
					Query.Text = StrReplace(Query.Text, "&ProviderFilter", "TRUE");
				EndIf;
				
				Query.SetParameter("Company",  DocumentAttributes.Company);
				Query.SetParameter("DocumentType",
					Catalogs.MetadataObjectIDs.FindByAttribute("FullName", "Document." + DocumentRef.Metadata().Name));
				
				QueryResult = Query.Execute();
				
				SelectionDetailRecords = QueryResult.Select();
				
				If SelectionDetailRecords.Next() Then
					Result = SelectionDetailRecords.Ref;
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Procedure AddCommands(Form, Commands, Val ItemForPlacement = Undefined)
	
	For Each CommandDescription In Commands Do
		
		CommandNumber = CommandDescription.Owner().IndexOf(CommandDescription);
		CommandName = ItemForPlacement.Name + CommandDescription.ID + CommandNumber;
		
		FormCommand = Form.Commands.Add(CommandName);
		FormCommand.Action = "Attachable_EDIExecuteCommand";
		FormCommand.Title = CommandDescription.Presentation;
		
		If ValueIsFilled(CommandDescription.Representation) Then
			FormCommand.Representation = CommandDescription.Representation;
		Else
			FormCommand.Representation = ButtonRepresentation.PictureAndText;
		EndIf;
		
		If ValueIsFilled(CommandDescription.Picture) Then
			FormCommand.Picture = CommandDescription.Picture;
		EndIf;
		
		CommandDescription.CommandNameAtForm = CommandName;
		
		NewItem = Form.Items.Add(CommandName, Type("FormButton"), ItemForPlacement);
		NewItem.Type = FormButtonType.CommandBarButton;
		NewItem.CommandName = CommandName;
		NewItem.Visible =  Not CommandDescription.Disabled;
		NewItem.OnlyInAllActions = CommandDescription.OnlyInAllActions
		
	EndDo;
	
EndProcedure

Procedure FillEDIState(Parameters)
	
	// StatusDescription
	EDI_StatusDescription = "EDI_StatusDescription";
	
	Form = Parameters.Form;
	FormAttributeList = Form.GetAttributes();
	CreateStatusDescription = True;
	For Each Attribute In FormAttributeList Do
		If Attribute.Name = EDI_StatusDescription Then
			CreateStatusDescription = False;
			Break;
		EndIf;
	EndDo;
	
	If CreateStatusDescription Then
		AttributesToAdd = New Array;
		String1500 = New TypeDescription("String", , New StringQualifiers(1500));
		AttributesToAdd.Add(New FormAttribute(EDI_StatusDescription, String1500));
		Form.ChangeAttributes(AttributesToAdd);
	EndIf;
	
	Ref = Parameters.Ref;
	StateDecoration = Parameters.StateDecoration;
	
	EDIState = Undefined;
	If Not Parameters.Property("EDIState", EDIState) Then
		EDIState = GetEDIState(Ref);
	EndIf;
	
	StateDecoration.Title = EDIState.Status;
	Form[EDI_StatusDescription] = EDIState.StatusDescription;
	
EndProcedure

Function ResultStructure()
	
	Result = New Structure;
	Result.Insert("ErrorsInEventLog", False);
	Result.Insert("ErrorsToShow", False);
	Result.Insert("ListOfErrorsToShow", New Array);
	
	Return Result;
	
EndFunction

#EndRegion





