
#Region ServiceProceduresAndFunctions

&AtClient
// Procedure fills in the description of payment document in the tabular field string
//
Procedure FillInPaymentDocumentDescription(DataCurrentRows, ThisCompanyData)
	
	If DataCurrentRows <> Undefined Then
		
		StringDataStructure = New Structure;
		StringDataStructure.Insert("AccountingDocument", DataCurrentRows.AccountingDocument);
		If ThisCompanyData Then
			
			StringDataStructure.Insert("DocumentNumber", DataCurrentRows.DocumentNumber);
			StringDataStructure.Insert("DocumentDate", DataCurrentRows.DocumentDate);
			
			// If you add it manually, consider that inc. number and data were specified by a user
			CompanyAccountingDocumentDescription(StringDataStructure);

		Else
			
			StringDataStructure.Insert("IncomingDocumentNumber", DataCurrentRows.IncomingDocumentNumber);
			StringDataStructure.Insert("IncomingDocumentDate", DataCurrentRows.IncomingDocumentDate);
			
			// If you add it manually, consider that inc. number and data were specified by a user
			CounterpartyAccountingDocumentDescription(StringDataStructure);

		EndIf;
		
		DataCurrentRows.DocumentDescription = StringDataStructure.DocumentDescription;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure clears document tabular sections
//
Procedure ClearDocumentData()
	
	Object.BalanceBeginPeriod = 0;
	Object.CompanyData.Clear();
	Object.CounterpartyData.Clear();
	
EndProcedure

&AtServer
Function GetCompanyData()
	
	CompanyData = New Structure;
	ContractByDefault = DriveServer.GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	CompanyData.Insert("ContractByDefault", ContractByDefault);
	
	If DoOperationsByContracts Then
		GetSettlementsCurrency(CompanyData, ContractByDefault);
	Else
		CompanyData.Insert("DocumentCurrency", Object.DocumentCurrency);
	EndIf;
	
	ProcessingCompanyVATNumbers(False);
	
	SetContractVisible();
	
	Return CompanyData;
	
EndFunction

&AtClient
// The procedure of the "Company data" tabular section filling by the accounting data
//
Procedure FillByBalance()
	
	FillByBalancesServer();
	CalculateSummaryDataDiscrepancy();
	
EndProcedure

&AtClient
// The procedure of the "Counterparty data" tabular section filling by the accounting data
//
Procedure FillCounterpartyInformationByCompanyData()
	
	FillByCompanyDataAtServer();
	CalculateSummaryDataDiscrepancy();
	
EndProcedure

&AtClient
// The procedure prepares the contracts array according to which an initial balance is calculated
//
Procedure CalculateInitialBalance()
	
	CalculateInitialBalanceAtServer();
	
EndProcedure

&AtServer
Procedure CalculateInitialBalanceAtServer()
	
	Object.BalanceBeginPeriod = Documents.ReconciliationStatement.BalanceByContracts(GetDocumentData(Object.Ref));
	
EndProcedure

&AtServer
// Calls the procedure of filling the counterparty empty dates on server
//
Procedure FillInDateInCounterpartyArisingFromSettlementDocuments()
	
	For Each DataRow In Object.CounterpartyData Do
		
		If ValueIsFilled(DataRow.IncomingDocumentDate) 
			OR Not ValueIsFilled(DataRow.AccountingDocument) Then
			
			Continue;
			
		EndIf;
		
		DataRow.IncomingDocumentDate	= DataRow.AccountingDocument.Date;
		DataRow.DocumentDescription		= Documents.ReconciliationStatement.CounterpartyAccountingDocumentDescription(
			DataRow.AccountingDocument,
			DataRow.IncomingDocumentNumber,
			DataRow.IncomingDocumentDate);
		
	EndDo;
	
EndProcedure

&AtServer
// The procedure generates structure with the document data
//
Function GetDocumentData(DocumentRef = Undefined)
	
	DocumentData = New Structure;
	DocumentData.Insert("Date",						Object.Date);
	DocumentData.Insert("BeginOfPeriod",			Object.BeginOfPeriod);
	DocumentData.Insert("EndOfPeriod", 				Object.EndOfPeriod);
	DocumentData.Insert("Company",					DriveServer.GetCompany(Object.Company));
	DocumentData.Insert("Ref",						DocumentRef);
	DocumentData.Insert("DocumentCurrency",			Object.DocumentCurrency);
	DocumentData.Insert("Counterparty",				Object.Counterparty);
	DocumentData.Insert("Contract",					Object.Contract);
	DocumentData.Insert("BalanceBeginPeriod",		Object.BalanceBeginPeriod);
	DocumentData.Insert("DoOperationsByContracts",	DoOperationsByContracts);
	
	Return DocumentData;
	
EndFunction

&AtServer
// The procedure of the "Company data" tabular section filling
//
Procedure FillByBalancesServer()
	
	Object.BalanceBeginPeriod = Documents.ReconciliationStatement.BalanceByContracts(GetDocumentData(Object.Ref));
	Documents.ReconciliationStatement.FillDataByCompany(GetDocumentData(), Object.CompanyData);
	
EndProcedure

&AtServer
// The procedure of the "Counterparty data" tabular section filling by the accounting data
//
Procedure FillByCompanyDataAtServer()
	
	Documents.ReconciliationStatement.FillCounterpartyInformationByCompanyData(Object.CompanyData, Object.CounterpartyData);
	
EndProcedure

&AtServerNoContext
// Fills in the description of the payment document and the contract currency in the CompanyData tabular section
//
// Parameters:
//    DocumentRef - DocumentRef - Ref to accounting document;
//    DocumentDescription - String - Variable to which the payment document description will be passed;
//    SettlementsCurrency - CatalogRef.Currencies - Variable to which the contract currency value will be passed
//
Function CompanyAccountingDocumentDescription(StringDataStructure)
	
	DocumentDescription = 
		Documents.ReconciliationStatement.CompanyAccountingDocumentDescription(StringDataStructure.AccountingDocument, StringDataStructure.DocumentNumber, StringDataStructure.DocumentDate);
	
	StringDataStructure.Insert("DocumentDescription", DocumentDescription);
	
EndFunction

&AtServerNoContext
// Fills in the payment document description and the contract currency in the CounterpartyData tabular section
//
// Parameters:
//    DocumentRef - DocumentRef - Ref to accounting document;
//    DocumentDescription - String - Variable to which the payment document description will be passed;
//    SettlementsCurrency - CatalogRef.Currencies - Variable to which the contract currency value will be passed
//
Function CounterpartyAccountingDocumentDescription(StringDataStructure)
	
	DocumentDescription = 
		Documents.ReconciliationStatement.CounterpartyAccountingDocumentDescription(StringDataStructure.AccountingDocument, StringDataStructure.IncomingDocumentNumber, StringDataStructure.IncomingDocumentDate);
	
	StringDataStructure.Insert("DocumentDescription", DocumentDescription);
	
EndFunction

&AtServer
// Sets the form items availability depending on the document status
//
Procedure SetEnabledOfItems()
	
	// Attributes are available only for the Created status
	CreatedStatus = (Object.Status = Enums.ReconciliationStatementStatus.Created);
	
	CommonClientServer.SetFormItemProperty(Items, "Company", "Enabled", CreatedStatus);
	CommonClientServer.SetFormItemProperty(Items, "PeriodGroupMatching", "Enabled", CreatedStatus);
	CommonClientServer.SetFormItemProperty(Items, "Counterparty", "Enabled", CreatedStatus);
	CommonClientServer.SetFormItemProperty(Items, "Group1", "Enabled", CreatedStatus);
	CommonClientServer.SetFormItemProperty(Items, "FillAccordingToAccounting", "Enabled", CreatedStatus);
	
	// Attributes are available for the Created and OnServer statuses
	StatusVerified = (Object.Status = Enums.ReconciliationStatementStatus.Verified);
	
	CommonClientServer.SetFormItemProperty(Items, "GroupBalanceCurrency", "Enabled", Not StatusVerified);
	CommonClientServer.SetFormItemProperty(Items, "CounterpartyDataFillByAccountingDocumentsDates", "Enabled", Not StatusVerified);
	CommonClientServer.SetFormItemProperty(Items, "FillAccordingToCompanies", "Enabled", Not StatusVerified);
	CommonClientServer.SetFormItemProperty(Items, "CounterpartyHeadNameAndSurname", "Enabled", Not StatusVerified);
	
	// Tabular sections are not included in the general rule.
	// To copy presentations, always leave them as available but do not allow editing (manage the property ViewOnly)
	CommonClientServer.SetFormItemProperty(Items, "CompanyData",	"ReadOnly", Not CreatedStatus);
	CommonClientServer.SetFormItemProperty(Items, "Documents", "ReadOnly", StatusVerified);
	
EndProcedure

&AtServer
// The procedure of receiving counterparty data
//
Procedure GetCounterpartyData(CounterpartyData)
	
	Object.CompanyData.Clear();
	Object.CounterpartyData.Clear();
	
	CounterpartyData = New Structure("ContactPerson");
	CounterpartyAttributes = Common.ObjectAttributesValues(Object.Counterparty, "DoOperationsByContracts, SettlementsCurrency");
	DoOperationsByContracts = CounterpartyAttributes.DoOperationsByContracts;	
	CommonClientServer.SetFormItemProperty(
		Items,
		"DescriptionContractsSelection",
		"Enabled",
		Object.Counterparty.DoOperationsByContracts);
	
	ContactPersonsList = DriveServer.GetCounterpartyContactPersons(Object.Counterparty);
	If ContactPersonsList.Count() > 0 Then
		CounterpartyData.ContactPerson = ContactPersonsList[0].Value;
	EndIf;
	
	ContractByDefault = DriveServer.GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company);
	CounterpartyData.Insert("ContractByDefault", ContractByDefault);
	
	If DoOperationsByContracts Then
		GetSettlementsCurrency(CounterpartyData, ContractByDefault);
	Else
		CounterpartyData.Insert("DocumentCurrency", CounterpartyAttributes.SettlementsCurrency);
	EndIf;
	
	SetContractVisible();
	
	Object.BalanceBeginPeriod = Documents.ReconciliationStatement.BalanceByContracts(GetDocumentData(Object.Ref));
	
EndProcedure

&AtServerNoContext
// The procedure of the received catalog data It is called after selecting a contract
// 
Procedure GetSettlementsCurrency(ContractData, Contract, Key = "DocumentCurrency")
	
	ContractData.Insert(Key, Common.ObjectAttributeValue(Contract, "SettlementsCurrency"));
	
EndProcedure

&AtServer
Procedure ContractOnChangeAtServer()
	
	If ValueIsFilled(Object.Contract) Then
		Object.DocumentCurrency = Common.ObjectAttributeValue(Object.Contract, "SettlementsCurrency");		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetContractVisible()
	
	If ValueIsFilled(Object.Counterparty) Then
		Items.Contract.Visible = DoOperationsByContracts;
	Else
		Items.Contract.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetCurrencyInHeader()
	
	Debits = NStr("en = 'Debits'; ru = 'Долг организации';pl = 'Zobowiązania';es_ES = 'Deudas';es_CO = 'Deudas';tr = 'Borçlar';it = 'Debiti';de = 'Lastschriften'");
	Credits = NStr("en = 'Credits'; ru = 'Долг контрагента';pl = 'Należności';es_ES = 'Créditos';es_CO = 'Créditos';tr = 'Alacaklar';it = 'Crediti';de = 'Guthaben'");
	
	Items.CompanyDataCounterpartyDebtDecreasingAmount.Title = Debits + ", " + Object.DocumentCurrency;
	Items.CompanyDataAmountIncreaseDebtCounterparty.Title = Credits + ", " + Object.DocumentCurrency;
	Items.CounterpartyDataSumDebtReductionCounterparty.Title = Debits + ", " + Object.DocumentCurrency;
	Items.CounterpartyDataCounterpartyDebtIncreasingAmount.Title = Credits + ", " + Object.DocumentCurrency;
	
EndProcedure

&AtClient
Procedure Attachable_ProcessDateChange()
	
	DateOnChangeAtServer();
	
	DocumentDate = Object.Date;
	
EndProcedure

&AtServer
Procedure DateOnChangeAtServer()
	ProcessingCompanyVATNumbers();
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	User = Users.CurrentUser();
	
	If TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
		Cancel = True;
		Return;
	EndIf;
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	SetEnabledOfItems();
	
	AccountingBySubsidiaryCompany = Constants.AccountingBySubsidiaryCompany.Get();
	If AccountingBySubsidiaryCompany Then
		
		// If you keep records on the company as a whole, it is required to delete the connection of selection by company
		LinkSelectParameters = New ChoiceParameterLink("Filter.Counterparty", "Object.Counterparty");
		NewArray = New Array;
		NewArray.Add(LinkSelectParameters);
		
		Items.CompanyDataAccountDocument.ChoiceParameterLinks = New FixedArray(NewArray);
		Items.CounterpartyDataCurrentDocument.ChoiceParameterLinks = New FixedArray(NewArray);
		
		If Not ValueIsFilled(Object.Company) Then
			
			Object.Company = Constants.ParentCompany.Get();
			
		EndIf;
		
	EndIf;
	
	DoOperationsByContracts = ?(ValueIsFilled(Object.Counterparty), Object.Counterparty.DoOperationsByContracts, False);
	CommonClientServer.SetFormItemProperty(Items, "DescriptionContractsSelection", "Enabled", DoOperationsByContracts);
	
	ProcessingCompanyVATNumbers();
	
	SetContractVisible();
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
// "OnOpen" event handler procedure of the document form
//
Procedure OnOpen(Cancel)
	
	SetCurrencyInHeader();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	If Not Object.Ref = Undefined Then
		CalculateSummaryDataDiscrepancy();
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
// "BeforeClosing" event handler procedure of the document form
//
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	// StandardSubsystems.AttachedFiles
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	// End StandardSubsystems.AttachedFiles
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure
	
#EndRegion

#Region FormItemEventsHandlers

&AtClient
// Procedure - "OnChange" event handler of the "Date" field.
//
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
EndProcedure

&AtClient
// Procedure - "Opening" event handler of the "CompanyDataDocumentDescription" field.
//
Procedure CompanyDataDetailsDocumentOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	DataCurrentRows = Items.CompanyData.CurrentData;
	If Not DataCurrentRows = Undefined Then
		
		If ValueIsFilled(DataCurrentRows.AccountingDocument) Then
			
			ShowValue(, DataCurrentRows.AccountingDocument);
			
		Else
			
			MessageText = NStr("en = 'The string is not bound to the payment document. 
			                   |To bind it, it is required to enable the visible of the corresponding column and specify a document.'; 
			                   |ru = 'Строка не привязана к расчетному документу. 
			                   |Для привязки необходимо включить видимость соответствующей колонки и указать документ самостоятельно.';
			                   |pl = 'Wiersz nie jest powiązany z dokumentem płatniczym. 
			                   |Aby go powiązać należy włączyć widoczność odpowiedniej kolumny i określić dokument.';
			                   |es_ES = 'La línea no está vinculada al documento de pago. 
			                   | Para vincularla, se requiere activar la visible de la columna correspondiente y especificar un documento.';
			                   |es_CO = 'La línea no está vinculada al documento de pago. 
			                   | Para vincularla, se requiere activar la visible de la columna correspondiente y especificar un documento.';
			                   |tr = 'Dize ödeme belgesine bağlı değil. 
			                   |Bağlamak için, ilgili sütunun görünürlüğünü etkinleştirmek ve bir belge belirtmek gerekir.';
			                   |it = 'La stringa non è vincolato al documento di pagamento.
			                   |Per associare esso, è necessario attivare il visibile della colonna corrispondente e specificare un documento.';
			                   |de = 'Die Zeichenfolge ist nicht an den Zahlungsbeleg gebunden.
			                   |Um sie zu binden, müssen Sie das Sichtbare der entsprechenden Spalte aktivieren und ein Dokument angeben.'");
				
			CommonClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - "Opening" event handler of the "CounterpartyDataDocumentDescription" field.
//
Procedure CounterpartyDataDetailsDocumentOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	DataCurrentRows = Items.CounterpartyData.CurrentData;
	
	If Not DataCurrentRows = Undefined Then
		
		If ValueIsFilled(DataCurrentRows.AccountingDocument) Then
			
			ShowValue(, DataCurrentRows.AccountingDocument);
			
		Else
			
			MessageText = NStr("en = 'The string is not bound to the payment document. 
			                   |To bind it, it is required to enable the visible of the corresponding column and specify a document.'; 
			                   |ru = 'Строка не привязана к расчетному документу. 
			                   |Для привязки необходимо включить видимость соответствующей колонки и указать документ самостоятельно.';
			                   |pl = 'Wiersz nie jest powiązany z dokumentem płatniczym. 
			                   |Aby go powiązać należy włączyć widoczność odpowiedniej kolumny i określić dokument.';
			                   |es_ES = 'La línea no está vinculada al documento de pago. 
			                   | Para vincularla, se requiere activar la visible de la columna correspondiente y especificar un documento.';
			                   |es_CO = 'La línea no está vinculada al documento de pago. 
			                   | Para vincularla, se requiere activar la visible de la columna correspondiente y especificar un documento.';
			                   |tr = 'Dize ödeme belgesine bağlı değil. 
			                   |Bağlamak için, ilgili sütunun görünürlüğünü etkinleştirmek ve bir belge belirtmek gerekir.';
			                   |it = 'La stringa non è vincolato al documento di pagamento.
			                   |Per associare esso, è necessario attivare il visibile della colonna corrispondente e specificare un documento.';
			                   |de = 'Die Zeichenfolge ist nicht an den Zahlungsbeleg gebunden.
			                   |Um sie zu binden, müssen Sie das Sichtbare der entsprechenden Spalte aktivieren und ein Dokument angeben.'");
				
			CommonClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;

EndProcedure

&AtClient
// Procedure - "OnChange" event handler of the "Status" field.
//
Procedure StatusOnChange(Item)
	
	SetEnabledOfItems()
	
EndProcedure

&AtClient
// Procedure - "OnChange" event handler of the "PaymentDocument" field of the "CounterpartyData" table.
//
Procedure CounterpartyDataAccountingDocumentOnChange(Item)
	
	DataCurrentRows = Items.CounterpartyData.CurrentData;
	FillInPaymentDocumentDescription(DataCurrentRows, False);
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the ByCounterpartyData tabular section.
//
Procedure CounterpartyDataOnChange(Item)
	
	CalculateSummaryDataDiscrepancy();
	
EndProcedure

&AtClient
// Procedure - "OnChange" event handler of the "PaymentDocument" field of the "CompanyData" table.
//
Procedure CompanyDataAccountingDocumentOnChange(Item)
	
	DataCurrentRows = Items.CompanyData.CurrentData;
	FillInPaymentDocumentDescription(DataCurrentRows, True);
	
EndProcedure

&AtClient
// Procedure - event handler  of the reconciliation status change
//
Procedure StatusChoiceProcessing(Item, ValueSelected, StandardProcessing)
	Var Errors, Cancel;
	
	If ValueSelected = PredefinedValue("Enum.ReconciliationStatementStatus.Verified") Then
		
		If Not ValueIsFilled(Object.Responsible) Then
			
			MessageText = NStr("en = 'Company responsible person is filled in incorrectly.'; ru = 'Неверно заполнено ответственное лицо организации.';pl = 'Nieprawidłowo wypełniono pole osoby odpowiedzialnej ze strony organizacji';es_ES = 'Persona responsable de la empres está rellenada de forma incorrecta.';es_CO = 'Persona responsable de la empres está rellenada de forma incorrecta.';tr = 'İş yeri yetkilisi yanlış doldurulmuştur.';it = 'La persona responsabile dell''azienda è stata compilata in modo errato.';de = 'Der Verantwortliche der Firma ist falsch ausgefüllt.'");
			CommonClientServer.AddUserError(Errors, "Object.Responsible", MessageText, Undefined);
			
		EndIf;
		
		If Not ValueIsFilled(Object.CounterpartyRepresentative) Then
			
			MessageText = NStr("en = 'Counterparty representative is filled in incorrectly.'; ru = 'Неверно заполнен представитель контрагента.';pl = 'Nieprawidłowo wypełniono pole przedstawiciela kontrahenta.';es_ES = 'Representante de la contraparte está rellenado de forma incorrecta.';es_CO = 'Representante de la contraparte está rellenado de forma incorrecta.';tr = 'Şirket temsilcisi yanlış doldurulmuştur.';it = 'Il rappresentante della controparte è compilato in modo errato.';de = 'Vertreter des Geschäftspartners ist falsch ausgefüllt.'");
			CommonClientServer.AddUserError(Errors, "Object.CounterpartyRepresentative", MessageText, Undefined);
			
		EndIf;
		
	EndIf;
	
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the counterparty field
//
Procedure CounterpartyOnChange(Item)
	Var CounterpartyData;
	
	ClearDocumentData();
	
	If ValueIsFilled(Object.Counterparty) Then
		
		GetCounterpartyData(CounterpartyData);
		Object.DocumentCurrency = CounterpartyData.DocumentCurrency;
		Object.CounterpartyRepresentative = CounterpartyData.ContactPerson;
		Object.Contract = CounterpartyData.ContractByDefault;
		
	EndIf;
	
	SetCurrencyInHeader();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the ByCompanyData tabular section.
//
Procedure CompanyDataOnChange(Item)
	
	CalculateSummaryDataDiscrepancy();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the Company attribute
//
Procedure CompanyOnChange(Item)
	
	ClearDocumentData();
	
	CompanyData = GetCompanyData();
	Object.DocumentCurrency = CompanyData.DocumentCurrency;
	Object.Contract = CompanyData.ContractByDefault;
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the PeriodStart attribute
//
Procedure BeginOfPeriodOnChange(Item)
	
	ClearDocumentData();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the PeriodStart attribute
//
Procedure EndOfPeriodOnChange(Item)
	
	ClearDocumentData();
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
EndProcedure

&AtClient
Procedure CounterpartyDataIncDateOnChange(Item)
	
	DataCurrentRows = Items.CounterpartyData.CurrentData;
	FillInPaymentDocumentDescription(DataCurrentRows, False);
	
EndProcedure

&AtClient
Procedure CounterpartyDataIncNumberOnChange(Item)
	
	DataCurrentRows = Items.CounterpartyData.CurrentData;
	FillInPaymentDocumentDescription(DataCurrentRows, False);
	
EndProcedure

&AtClient
Procedure CompanyDataDocumentDateOnChange(Item)
	
	DataCurrentRows = Items.CompanyData.CurrentData;
	FillInPaymentDocumentDescription(DataCurrentRows, True);
	
EndProcedure

&AtClient
Procedure CompanyDataDocumentNumberOnChange(Item)
	
	DataCurrentRows = Items.CompanyData.CurrentData;
	FillInPaymentDocumentDescription(DataCurrentRows, True);
	
EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	ContractOnChangeAtServer();
	SetCurrencyInHeader();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
// Calls the initialization procedure of the empty incoming dates with the payment document dates
//
Procedure FillByAccountingDocumentsDates(Command)
	
	If Object.CounterpartyData.Count() < 1 Then
		
		MessageText = NStr("en = 'Tabular section of counterparty reconciliation data is empty.'; ru = 'Табличная часть взаиморасчетов по данным контрагента пуста.';pl = 'Sekcja tabelaryczna danych uzgadniania z kontrahentem jest pusta.';es_ES = 'Sección tabular de los datos de la reconciliación de la contraparte está vacía.';es_CO = 'Sección tabular de los datos de la reconciliación de la contraparte está vacía.';tr = 'Cari hesap uzlaşma verilerinin sekmeli bölümü boştur.';it = 'La sezione tabellare dei dati della riconciliazione dell controparte è vuota.';de = 'Der tabellarische Teil der Abstimmungsdaten des Geschäftspartners ist leer.'");
		CommonClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	FillInDateInCounterpartyArisingFromSettlementDocuments();
	
EndProcedure

&AtClient
// Procedure - "FillInByBalanceCommand" command handler.
//
Procedure FillAccordingToAccounting(Command)
	
	CallProcedureToFillTableParts = True;
	
	If Not ValueIsFilled(Object.EndOfPeriod) Then
		
		MessageText	= NStr("en = 'The period end date is filled in incorrectly.'; ru = 'Неверно заполнена дата окончания периода.';pl = 'Nieprawidłowo wypełniona data zakończenia okresu.';es_ES = 'La fecha del fin del período está rellenada de forma incorrecta.';es_CO = 'La fecha del fin del período está rellenada de forma incorrecta.';tr = 'Dönem sonu tarihi yanlış dolduruldu.';it = 'La data di fine periodo è stata inserita non correttamente.';de = 'Das Enddatum des Zeitraums ist falsch ausgefüllt.'");
		MessageField	= "Object.EndOfPeriod";
		
		CommonClientServer.MessageToUser(MessageText, , MessageField);
		
		CallProcedureToFillTableParts = False;
		
	EndIf;
	
	
	If CallProcedureToFillTableParts Then
		
		If Object.CompanyData.Count() > 0 Then
			
			QuestionText	= NStr("en = 'Tabular section will be cleared and filled in again. Do you want to continue?'; ru = 'Табличная часть будит очищена и повторно заполнена. Продолжить?';pl = 'Sekcja tabelaryczna zostanie wyczyszczona i wypełniona ponownie. Czy chcesz kontynuować?';es_ES = 'Sección tabular se eliminará y rellenará de nuevo. ¿Quiere continuar?';es_CO = 'Sección tabular se eliminará y rellenará de nuevo. ¿Quiere continuar?';tr = 'Tablo bölümü silinip tekrar doldurulacak. Devam etmek istiyor musunuz?';it = 'La sezione tabella sarà annullata e compilata nuovamente. Volete proseguire?';de = 'Der Tabellenabschnitt wird gelöscht und erneut ausgefüllt. Möchten Sie diesen Vorgang fortsetzen?'");
			NotifyDescription = New NotifyDescription("HandlerAfterQuestionAboutCleaning", ThisObject, "CompanyData");
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			FillByBalance();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// The procedure fills in the Counterparty data tabular field by the company data
//
//
Procedure TransferFromCompanyData(Command)
	
	If Object.CompanyData.Count() < 1 Then
		
		MessageText = NStr("en = 'Tabular section with company data is not filled in.'; ru = 'Не заполнена табличная часть с данными организации.';pl = 'Nie wypełniona tabelaryczna część z danymi firmy.';es_ES = 'Sección tabular con los datos de la empres no está rellenada.';es_CO = 'Sección tabular con los datos de la empres no está rellenada.';tr = 'İş yeri bilgileri olan sekmeli bölüm doldurulmamıştır.';it = 'La sezione tabellare con i dati aziendali non è compilata.';de = 'Tabellenabschnitt mit Firmendaten ist nicht ausgefüllt.'");
		CommonClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	If Object.CounterpartyData.Count() > 0 Then
		
		QuestionText	= NStr("en = 'Tabular section will be cleared and filled in again. Continue?'; ru = 'Табличная часть будит очищена и заполнена повторно. Продолжить?';pl = 'Sekcja tabelaryczna zostanie wyczyszczona i wypełniona ponownie. Kontynuować?';es_ES = 'Sección tabular se eliminará y rellenará de nuevo. ¿Continuar?';es_CO = 'Sección tabular se eliminará y rellenará de nuevo. ¿Continuar?';tr = 'Tablo bölümü silinip tekrar doldurulacak. Devam edilsin mi?';it = 'La sezione tabellare viene cancellata e riempita di nuovo. Continuare?';de = 'Der Tabellenabschnitt wird gelöscht und erneut ausgefüllt. Fortsetzen?'");
		NotifyDescription = New NotifyDescription("HandlerAfterQuestionAboutCleaning", ThisObject, "CounterpartyData");
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, 0);
		
	Else
		
		FillCounterpartyInformationByCompanyData();
		
	EndIf;
	
EndProcedure

&AtClient
// The procedure calculates the data variance and fills in the required attributes
//
Procedure CalculateSummaryDataDiscrepancy()
	
	BalanceByCompanyData	= Object.CompanyData.Total("ClientDebtAmount") - Object.CompanyData.Total("CompanyDebtAmount");
	BalanceByCounterpartyData	= Object.CounterpartyData.Total("CompanyDebtAmount") - Object.CounterpartyData.Total("ClientDebtAmount");
	
	Discrepancy					= BalanceByCompanyData - BalanceByCounterpartyData;
	
EndProcedure

&AtClient
// Procedure - command handler "SetInterval".
//
Procedure SetInterval(Command)
	
	Dialog = New StandardPeriodEditDialog();
	Dialog.Period.StartDate = Object.BeginOfPeriod;
	Dialog.Period.EndDate = Object.EndOfPeriod;
	
	NotifyDescription = New NotifyDescription("AfterSelectingFillingPeriod", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
// Procedure - CalculateInitialBalance command handler
//
Procedure InitialBalance(Command)
	
	CalculateInitialBalance();
	
EndProcedure

#EndRegion

#Region InteractiveActionResultHandlers

&AtClient
// The procedure processes the result of question on TS clearing 
//
Procedure HandlerAfterQuestionAboutCleaning(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		If AdditionalParameters = "CompanyData" Then
			
			FillByBalance();
			
		ElsIf AdditionalParameters = "CounterpartyData" Then
			
			FillCounterpartyInformationByCompanyData()
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// The procedure processes the period selection result of the current document filling
//
Procedure AfterSelectingFillingPeriod(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult <> Undefined Then
		
		ClearDocumentData();
		If Object.BeginOfPeriod <> ClosingResult.StartDate Then
			
			Object.BeginOfPeriod = ClosingResult.StartDate;
			CalculateInitialBalance();
			
		EndIf;
		
		Object.EndOfPeriod = ClosingResult.EndDate;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Object);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Object, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributeItems()
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
EndProcedure

// End StandardSubsystems.Properties

#EndRegion
