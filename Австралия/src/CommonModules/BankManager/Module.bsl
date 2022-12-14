#Region Public

// Receives, sorts, writes bank classifier data from site.
// 
// Parameters:
// ClassifierImportParameters - Map:
// Exported						- Number	 - Classifier new records quantity.
// Updated						- Number	 - Quantity of updated classifier records.
// MessageText					- String - import results message text.
// ImportCompleted              - Boolean - check box of successful classifier data import end.
// StorageAddress				- String - internal storage address.
Procedure GetWebsiteData(ClassifierImportParameters, StorageAddress = "") Export
	
	DataProcessorManager = GetBankClassifierImportProcessor();
	DataProcessorManager.ImportDataFromWeb(ClassifierImportParameters, StorageAddress);
	
	SetClassifierVersion();
	SupplementMessageText(ClassifierImportParameters);
	
	If Not IsBlankString(StorageAddress) Then
		PutToTempStorage(ClassifierImportParameters, StorageAddress);
	EndIf;

EndProcedure

// Receives, writes classifier data from file.
// 
// Parameters:
// FilesImportingParameters		 - Map:
// Exported						 - Number		      - Classifier new records quantity.
// Updated						 - Number			  - Quantity of updated classifier records.
// MessageText					 - String			  - import results message text.
// ImportCompleted                - Boolean             - check box of successful classifier data import end.
//
Procedure ImportDataFile(FilesImportingParameters, StorageAddress = "") Export
	
	DataProcessorManager = GetBankClassifierImportProcessor();
	DataProcessorManager.ImportDataFromFile(FilesImportingParameters, StorageAddress);
	
	SetClassifierVersion();
	
	If IsBlankString(FilesImportingParameters["MessageText"]) Then
		FilesImportingParameters.Insert("ImportCompleted", True);
		SupplementMessageText(FilesImportingParameters);
	EndIf;
	
	If Not IsBlankString(StorageAddress) Then
		PutToTempStorage(FilesImportingParameters, StorageAddress);
	EndIf;

EndProcedure

// Returns text comment on a reason a bank is marked as inactive.
//
// Parameters:
//  Bank - CatalogRef.BankClassifier - the bank to get the text comment for.
//
// Returns:
//  FormattedString - the comment.
//
Function InvalidBankNote(Bank) Export
	
	BankDescription = Common.ObjectAttributeValue(Bank, "Description");
	
	QueryText =
	"SELECT
	|	BankClassifier.Ref,
	|	BankClassifier.Code AS BIC
	|FROM
	|	Catalog.BankClassifier AS BankClassifier
	|WHERE
	|	BankClassifier.Ref <> &Ref
	|	AND BankClassifier.Description = &Description
	|	AND NOT BankClassifier.OutOfBusiness";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Bank);
	Query.SetParameter("Description", BankDescription);
	Selection = Query.Execute().Select();
	
	NewBankDetails = Undefined;
	If Selection.Next() Then
		NewBankDetails = New Structure("Ref, BIC", Selection.Ref, Selection.BIC);
	EndIf;
	
	If ValueIsFilled(Bank) AND ValueIsFilled(NewBankDetails) Then
		Result = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '?????? ?????????? ?????????????????? ???? <a href = ""%1"">%2</a>'; en = 'Bank BIC changed to <a href = ""%1"">%2</a>'; pl = 'Zmieniono BIC banku na <a href = ""%1"">%2</a>';es_ES = 'BIC del banco se ha cambiado <a href = ""%1"">%2</a>';es_CO = 'BIC del banco se ha cambiado <a href = ""%1"">%2</a>';tr = 'Banka BIC <a href = ""%1"">%2</a> olarak de??i??tirildi';it = 'Lo SWIFT della banca ?? stato modificato in <a href = ""%1"">%2</a>';de = 'Bank BIC ge??ndert zu <a href = ""%1"">%2</a>'"),
			GetURL(NewBankDetails.Ref), NewBankDetails.BIC);
	Else
		Result = NStr("ru = '???????????????????????? ?????????? ????????????????????'; en = 'Bank activity is ceased'; pl = 'Dzia??alno???? banku zosta??a zako??czona';es_ES = 'Actividad bancaria cesada';es_CO = 'Actividad bancaria cesada';tr = 'Banka aktivitesi durdurulmu??tur';it = 'L''attivit?? della banca ?? cessata';de = 'Bankt??tigkeit wurde beendet'");
	EndIf;
	
	Return StringFunctionsClientServer.FormattedString(Result);
	
EndFunction

// Generates fields structure for settings.
// If you use import from the site you should set "UseImportFromSite" to "True"
// If you use import from the file you should set "UseImportFromFile" to "True"
// You can use both methods.
//
// If you use import from Web you need to set:
//  - Protocol;
//  - Port;
//  - ServerSource;
//  - Address;
//  - ClassifierFileOnWeb;
//
// Returns:
//   Settings - Structure - Additional data processor settings
//
Function Settings() Export

	Settings = New Structure;
	Settings.Insert("UseImportFromWeb", 	False);
	Settings.Insert("UseImportFromFile", 	True);
	Settings.Insert("Protocol", 			"");
	Settings.Insert("Port", 				Undefined);
	Settings.Insert("ServerSource", 		"");
	Settings.Insert("Address", 				"");
	Settings.Insert("ClassifierFileOnWeb",	"");
	
	DataProcessorManager = GetBankClassifierImportProcessor();	
	DataProcessorManager.OnDefineSettings(Settings);
	
	Return Settings;

EndFunction

Procedure ExecuteImportFromFile(ParametersStructure, BackgroundJobStorageAddress = "") Export

	ResultStructure = New Structure;
	ResultStructure.Insert("JobName",		"ExecuteImportFromFile");
	ResultStructure.Insert("Done",			True);
	ResultStructure.Insert("Errors",		Undefined);
	ResultStructure.Insert("ImportedTable",	ParametersStructure.ImportedTable);
	
	ParametersStructure.Delete("ImportedTable");
	
	Try
		DataProc = AdditionalReportsAndDataProcessors.GetExternalDataProcessorsObject(ParametersStructure.ExchangeSettings.DataProcessor);
		DataProc.ImportDataFromFile(ParametersStructure, ResultStructure);
	Except
		ResultStructure.Done = False;
		CommonClientServer.AddUserError(
			ResultStructure.Errors,
			"",
			BriefErrorDescription(ErrorInfo()),
			"");
	EndTry;
	
	If ResultStructure.Done
		AND ResultStructure.ImportedTable.Count() = 0 Then
		ResultStructure.Done = False;
		CommonClientServer.AddUserError(
			ResultStructure.Errors,
			"",
			NStr("en = 'Bank transactions not found in the file'; ru = '???? ?????????????? ???????????????????? ???????????????????? ?? ??????????';pl = 'W pliku nie znaleziono transakcji bankowych';es_ES = 'Transacciones bancarias no encontradas en el archivo';es_CO = 'Transacciones bancarias no encontradas en el archivo';tr = 'Banka i??lemleri dosyada bulunmad??';it = 'Le operazioni con la banca non sono state trovate nel file';de = 'Bankbewegungen wurden in der Datei nicht gefunden'"),
			"");
	EndIf;
	
	PutToTempStorage(ResultStructure, BackgroundJobStorageAddress);
	
EndProcedure

Procedure ExecuteExportToFile(ParametersStructure, BackgroundJobStorageAddress = "") Export
	
	ResultStructure = New Structure;
	ResultStructure.Insert("JobName",		"ExecuteExportToFile");
	ResultStructure.Insert("Done",			True);
	ResultStructure.Insert("Errors",		Undefined);
	ResultStructure.Insert("BinaryData",	"");
	
	Try
		DataProc = AdditionalReportsAndDataProcessors.GetExternalDataProcessorsObject(ParametersStructure.ExchangeSettings.DataProcessor);
		DataProc.ExportDataToFile(ParametersStructure, ResultStructure);
	Except
		ResultStructure.Done = False;
		CommonClientServer.AddUserError(
			ResultStructure.Errors,
			"",
			BriefErrorDescription(ErrorInfo()),
			"");
	EndTry;
	
	If ResultStructure.Done
		AND TypeOf(ResultStructure.BinaryData) <> Type("BinaryData") Then
		ResultStructure.Done = False;
		CommonClientServer.AddUserError(
			ResultStructure.Errors,
			"",
			NStr("en = 'No data to write to file'; ru = '?????? ???????????? ?????? ???????????? ?? ????????';pl = 'Plik nie zawiera danych do zapisu';es_ES = 'No hay datos para grabar en el archivo';es_CO = 'No hay datos para grabar en el archivo';tr = 'Dosyaya yaz??lacak veri bulunmad??';it = 'Non sono disponibili dati per scrivere il file';de = 'Keine Daten zum Schreiben in die Datei'"),
			"");
	EndIf;
	
	PutToTempStorage(ResultStructure, BackgroundJobStorageAddress);
	
EndProcedure

Procedure ExecuteCreateImportDocuments(ParametersStructure, BackgroundJobStorageAddress = "") Export
	
	ResultStructure = New Structure;
	ResultStructure.Insert("JobName",		"ExecuteCreateImportDocuments");
	ResultStructure.Insert("Done",			True);
	ResultStructure.Insert("Errors",		Undefined);
	ResultStructure.Insert("ImportTable",	"");
	
	Try
		CreateImportDocuments(ParametersStructure, ResultStructure);
	Except
		ResultStructure.Done = False;
		CommonClientServer.AddUserError(
			ResultStructure.Errors,
			"",
			BriefErrorDescription(ErrorInfo()),
			"");
	EndTry;
	
	PutToTempStorage(ResultStructure, BackgroundJobStorageAddress);
	
EndProcedure

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	If Metadata.DataProcessors.Find("ImportBankClassifier") <> Undefined Then
		DataProcessors["ImportBankClassifier"].OnAddUpdateHandlers(Handlers);
	EndIf;
	
EndProcedure

// See ImportDataFromFileOverridable.OnDefineCatalogsForDataImport. 
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	// Import to BankClassifier is denied.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.BankClassifier.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;
	
EndProcedure

// See BatchObjectModificationOverridable.OnDetermineObjectsWithEditableAttributes. 
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.BankClassifier.FullName(), "AttributesToSkipInBatchProcessing");
EndProcedure

// See UsersOverridable.OnDefineRolesAssignment. 
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// ForSystemUsersOnly.
	RolesAssignment.ForSystemUsersOnly.Add(
		Metadata.Roles.AddEditBanks.Name);
	
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings. 
Procedure OnDefineScheduledJobSettings(Dependencies) Export
	DataProcessorName = "ImportBankClassifier";
	If Metadata.DataProcessors.Find(DataProcessorName) <> Undefined Then
		DataProcessors[DataProcessorName].OnDefineScheduledJobSettings(Dependencies);
	EndIf;
EndProcedure

// See ExportImportDataOverridable.OnFillCommonDataTypesSupportingReferenceComparisonOnImport. 
Procedure OnFillCommonDataTypesSupportingRefMappingOnExport(Types) Export
	
	Types.Add(Metadata.Catalogs.BankClassifier);
	
EndProcedure

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	DataProcessorName = "ImportBankClassifier";
	If Metadata.DataProcessors.Find(DataProcessorName) = Undefined Then
		Return;
	EndIf;
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Common.DataSeparationEnabled() // Automatic update in SaaS mode.
		Or Common.IsSubordinateDIBNode() // The distributed infobase node is updated automatically.
		Or Not AccessRight("Update", Metadata.Catalogs.BankClassifier)
		Or ModuleToDoListServer.UserTaskDisabled("BankClassifier") Then
		Return;
	EndIf;
	
	Result = DataProcessors[DataProcessorName].BankClassifierRelevance();
	
	// This procedure is only called when To-do list subsystem is available. Therefore, the subsystem 
	// availability check is redundant.
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.Catalogs.BankClassifier.FullName());
	
	For Each Section In Sections Do
		
		IdentifierBanks = "BankClassifier" + StrReplace(Section.FullName(), ".", "");
		UserTask = ToDoList.Add();
		UserTask.ID  = IdentifierBanks;
		UserTask.HasUserTasks       = Result.ClassifierOutdated;
		UserTask.Important         = Result.ClassifierExpired;
		UserTask.Presentation  = NStr("ru = '?????????????????????????? ???????????? ??????????????'; en = 'Bank classifier is outdated'; pl = 'Klasyfikator bankowy jest nieaktualny';es_ES = 'Clasificador de bancos est?? desactualizado';es_CO = 'Clasificador de bancos est?? desactualizado';tr = 'Banka s??n??fland??r??c?? zaman a????m??na u??ram????';it = 'Il Classificatore Banche ?? obsoleto';de = 'Bank-Klassifikator ist veraltet'");
		UserTask.ToolTip      = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '?????????????????? ???????????????????? %1 ??????????'; en = 'Last update was %1 ago'; pl = 'Ostatnia aktualizacja mia??a miejsce %1 temu';es_ES = '??ltima actualizaci??n se ha hecho hace %1';es_CO = '??ltima actualizaci??n se ha hecho hace %1';tr = 'Son g??ncelleme %1??nceydi';it = 'Ultimo aggiornamento su %1 indietro';de = 'Letzte Aktualisierung war vor %1'"), Result.ExpiredPeriodString);
		UserTask.Form          = "DataProcessor.ImportBankClassifier.Form.ImportClassifier";
		UserTask.FormParameters = New Structure("OpeningFromList", True);
		UserTask.Owner       = Section;
		
	EndDo;
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart. 
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	ShowMessageOnInvalidity = (
		Not Common.DataSeparationEnabled() // Automatic update in SaaS mode.
		AND Not Common.IsSubordinateDIBNode() // The distributed infobase node is updated automatically.
		AND AccessRight("Update", Metadata.Catalogs.BankClassifier) //  A user with sufficient rights.
		AND Not ClassifierUpToDate()); // Classifier is already updated.
	
	EnableNotifications = Not Common.SubsystemExists("StandardSubsystems.ToDoList");
	BankOperationsOverridable.OnDetermineIfOutdatedClassifierWarningRequired(EnableNotifications);
	
	Parameters.Insert("Banks", New FixedStructure("ShowMessageOnInvalidity", (ShowMessageOnInvalidity AND EnableNotifications)));
	
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources. 
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	PermissionRequests.Add(
		ModuleSafeModeManager.RequestToUseExternalResources(Permissions()));
	
EndProcedure

// See OnlineSupportOverridable.OnSaveOnlineSupportUserAuthenticationData. 
Procedure OnSaveOnlineSupportUserAuthenticationData(UserData) Export
	
	If Metadata.DataProcessors.Find("ImportBankClassifier") <> Undefined Then
		DataProcessors["ImportBankClassifier"].OnSaveOnlineSupportUserAuthenticationData(UserData);
	EndIf;
	
EndProcedure

// See OnlineSupportOverridable.OnDeleteOnlineSupportUserAuthenticationData. 
Procedure OnDeleteOnlineSupportUserAuthenticationData() Export
	
	If Metadata.DataProcessors.Find("ImportBankClassifier") <> Undefined Then
		DataProcessors["ImportBankClassifier"].OnDeleteOnlineSupportUserAuthenticationData();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

#Region BankStatementDocumentCreation

Procedure CreateImportDocuments(ParametersStructure, ResultStructure)
	
	ImportTable = ParametersStructure.ImportTable;
	
	AutomaticallyFillInDebts = ParametersStructure.AutomaticallyFillInDebts;
	
	Counter = 0;
	
	For Each SectionRow In ImportTable Do
		If SectionRow.Mark Then
			
			If Not ValueIsFilled(SectionRow.Document) Then
				ObjectOfDocument = Documents[SectionRow.DocumentKind].CreateDocument();
				IsNewDocument = True;
			Else
				ObjectOfDocument = SectionRow.Document.GetObject();
				IsNewDocument = False;
			EndIf;
			
			If SectionRow.DocumentKind = "PaymentExpense" Then
				FillAttributesPaymentExpense(ObjectOfDocument, SectionRow, IsNewDocument);
			ElsIf SectionRow.DocumentKind = "PaymentReceipt" Then
				FillAttributesPaymentReceipt(ObjectOfDocument, SectionRow, IsNewDocument);
			EndIf;
			
			WriteObject(ObjectOfDocument, SectionRow, IsNewDocument, AutomaticallyFillInDebts, ResultStructure, Counter);
			
			If NOT ValueIsFilled(SectionRow.Document) Then
				SectionRow.Document = ObjectOfDocument.Ref;
			EndIf;
			
		EndIf;
	EndDo;
	
	CommonClientServer.AddUserError(
		ResultStructure.Errors,
		"",
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 lines imported successfully.'; ru = '?????????? ?????????????? ??????????????????????????: %1';pl = 'Pomy??lny import %1 linii.';es_ES = '%1 l??neas importadas con ??xito.';es_CO = '%1 l??neas importadas con ??xito.';tr = '%1 sat??r i??e aktar??ld??.';it = '%1 linee importate con successo.';de = '%1 Zeilen erfolgreich importiert.'"),
			Counter),
		"");
	
	ResultStructure.ImportTable = ImportTable;
	
EndProcedure

Procedure SetProperty(Object, PropertyName, PropertyValue, IsNewDocument, RequiredReplacementOfOldValues = False)
	
	If PropertyValue <> Undefined
		AND Object[PropertyName] <> PropertyValue
		AND (IsNewDocument
			OR (NOT ValueIsFilled(Object[PropertyName])
			OR RequiredReplacementOfOldValues)
			OR TypeOf(Object[PropertyName]) = Type("Boolean")
			OR TypeOf(Object[PropertyName]) = Type("Date"))Then
			
			Object[PropertyName] = PropertyValue;
			
	EndIf;
	
EndProcedure

Procedure CalculateRateAndAmountOfAccounts(StringPayment, SettlementsCurrency, ExchangeRateDate, ObjectOfDocument, IsNewDocument)
	
	StructureRateCalculations = CurrencyRateOperations.GetCurrencyRate(ExchangeRateDate, SettlementsCurrency, ObjectOfDocument.Company);
	StructureRateCalculations.Rate = ?(StructureRateCalculations.Rate = 0, 1, StructureRateCalculations.Rate);
	StructureRateCalculations.Repetition = ?(StructureRateCalculations.Repetition = 0, 1, StructureRateCalculations.Repetition);
	
	SetProperty(
		StringPayment,
		"ExchangeRate",
		StructureRateCalculations.Rate,
		IsNewDocument);
		
	SetProperty(
		StringPayment,
		"Multiplicity",
		StructureRateCalculations.Repetition,
		IsNewDocument);
		
	DocumentRateStructure = CurrencyRateOperations.GetCurrencyRate(ExchangeRateDate, ObjectOfDocument.CashCurrency, ObjectOfDocument.Company);
	
	SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
		StringPayment.PaymentAmount,
		DriveServer.GetExchangeMethod(ObjectOfDocument.Company),
		DocumentRateStructure.Rate,
		StructureRateCalculations.Rate,
		DocumentRateStructure.Repetition,
		StructureRateCalculations.Repetition);
	
	SetProperty(
		StringPayment,
		"SettlementsAmount",
		SettlementsAmount,
		IsNewDocument,
		True);
	
EndProcedure

Function GetObjectPresentation(Object)
	
	If TypeOf(Object) = Type("DocumentObject.PaymentReceipt") Then
		NameObject = NStr("en = 'Payment receipt'; ru = '?????????????????????? ???? ????????';pl = 'P??atno???? wchodz??ca';es_ES = 'Recibo del pago';es_CO = 'Recibo del pago';tr = '??deme fi??i';it = 'Ricevuta di pagamento';de = 'Zahlungsbeleg'");
	ElsIf TypeOf(Object) = Type("DocumentObject.PaymentExpense") Then
		NameObject = NStr("en = 'Bank payment'; ru = '???????????????? ???? ??????????';pl = 'P??atno???? bankowa';es_ES = 'Pago bancario';es_CO = 'Pago bancario';tr = 'Banka ??demesi';it = 'Bonifico bancario';de = '??berweisung'");
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 document #%2 dated %3'; ru = '???????????????? %1 ???%2 ???? %3';pl = 'dokument %1 nr %2 z dn. %3';es_ES = '%1 documento #%2 fechado %3';es_CO = '%1 documento #%2 fechado %3';tr = '%1 belge no%2 tarih %3';it = '%1 documento #%2 con data %3';de = '%1 Dokument Nr %2 datiert %3'"),
			NameObject,
			String(TrimAll(Object.Number)),
			String(Object.Date));
	
EndFunction

Procedure FillAttributesPaymentExpense(ObjectOfDocument, SourceData, IsNewDocument)
	
	// Filling out a document header.
	SetProperty(
		ObjectOfDocument,
		"Date",
		SourceData.Received,
		IsNewDocument);
	
	SetProperty(
		ObjectOfDocument,
		"OperationKind",
		SourceData.OperationKind,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"Company",
		SourceData.Company,
		IsNewDocument);
	
	SetProperty(
		ObjectOfDocument,
		"BankAccount",
		SourceData.BankAccount,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"CashCurrency",
		SourceData.BankAccount.CashCurrency,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"Item",
		SourceData.CFItem,
		True,
		IsNewDocument);
	
	SetProperty(
		ObjectOfDocument,
		"DocumentAmount",
		SourceData.Amount,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"ExternalDocumentNumber",
		SourceData.ExternalDocumentNumber,
		IsNewDocument);
	
	SetProperty(
		ObjectOfDocument,
		"ExternalDocumentDate",
		SourceData.ExternalDocumentDate,
		IsNewDocument);
		
	SetProperty(
		ObjectOfDocument,
		"Paid",
		True,
		IsNewDocument);
		
	SetProperty(
		ObjectOfDocument,
		"PaymentDate",
		SourceData.PaymentDate,
		IsNewDocument);
	
	If IsNewDocument Then
		ObjectOfDocument.SetNewNumber();
		If SourceData.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer Then
			ObjectOfDocument.VATTaxation = DriveServer.VATTaxation(SourceData.Company, SourceData.Received);
		ElsIf SourceData.OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements
			Or SourceData.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToEmployee Then
			ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
		Else
			ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
		EndIf;
	EndIf;
	
	// Filling document tabular section.
	If SourceData.OperationKind = Enums.OperationTypesPaymentExpense.Vendor
			Or SourceData.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer
			Or SourceData.OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements
			Or SourceData.OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements Then
		
		If TypeOf(SourceData.CounterpartyBankAccount) <> Type("String") Then
			SetProperty(
				ObjectOfDocument,
				"CounterpartyAccount",
				SourceData.CounterpartyBankAccount,
				IsNewDocument);
		EndIf;
			
		SetProperty(
			ObjectOfDocument,
			"Counterparty",
			SourceData.Counterparty,
			IsNewDocument);
		
		If ObjectOfDocument.PaymentDetails.Count() = 0 Then
			RowOfDetails = ObjectOfDocument.PaymentDetails.Add();
		Else
			RowOfDetails = ObjectOfDocument.PaymentDetails[0];
		EndIf;
		
		OneRowInDecipheringPayment = ObjectOfDocument.PaymentDetails.Count() = 1;
		
		SetProperty(
			RowOfDetails,
			"Contract",
			SourceData.Contract,
			IsNewDocument);
			
		If SourceData.OperationKind <> Enums.OperationTypesPaymentExpense.LoanSettlements Then
			SetProperty(
				RowOfDetails,
				"AdvanceFlag",
				SourceData.AdvanceFlag,
				IsNewDocument,
				True);
		EndIf;
			
		SetProperty(
			RowOfDetails,
			"Item",
			SourceData.CFItem,
			True,
			IsNewDocument);
	
		If IsNewDocument
			Or OneRowInDecipheringPayment
				And RowOfDetails.PaymentAmount <> ObjectOfDocument.DocumentAmount Then
		
			RowOfDetails.PaymentAmount	= ObjectOfDocument.DocumentAmount;
			DateOfFilling				= ObjectOfDocument.Date;
			SettlementsCurrency			= RowOfDetails.Contract.SettlementsCurrency;
			
			CalculateRateAndAmountOfAccounts(
				RowOfDetails,
				SettlementsCurrency,
				DateOfFilling,
				ObjectOfDocument,
				IsNewDocument);
			
			If RowOfDetails.ExchangeRate = 0 Then
				
				SetProperty(
					RowOfDetails,
					"ExchangeRate",
					1,
					IsNewDocument);
				
				SetProperty(
					RowOfDetails,
					"Multiplicity",
					1,
					IsNewDocument);
				
				SetProperty(
					RowOfDetails,
					"SettlementsAmount",
					RowOfDetails.PaymentAmount,
					IsNewDocument);
				
			EndIf;
			
			If ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
				
				DefaultVATRate	= InformationRegisters.AccountingPolicy.GetDefaultVATRate(ObjectOfDocument.Date, ObjectOfDocument.Company);
				VATRateValue	= DriveReUse.GetVATRateValue(DefaultVATRate);
				
				RowOfDetails.VATRate	= DefaultVATRate;
				RowOfDetails.VATAmount	= RowOfDetails.PaymentAmount - (RowOfDetails.PaymentAmount) / ((VATRateValue + 100) / 100);
				
			Else
				
				If ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
					DefaultVATRate = Catalogs.VATRates.Exempt;
				Else
					DefaultVATRate = Catalogs.VATRates.ZeroRate;
				EndIf;
				
				RowOfDetails.VATRate	= DefaultVATRate;
				RowOfDetails.VATAmount	= 0;
				
			EndIf;
			
		EndIf;
	ElsIf SourceData.OperationKind = Enums.OperationTypesPaymentExpense.IssueLoanToCounterparty
		Or SourceData.OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements
		Or SourceData.OperationKind = Enums.OperationTypesPaymentExpense.Other
		Or SourceData.OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements
		Or SourceData.OperationKind = Enums.OperationTypesPaymentExpense.Taxes Then
		
		If TypeOf(SourceData.CounterpartyBankAccount) <> Type("String") Then
			SetProperty(
				ObjectOfDocument,
				"CounterpartyAccount",
				SourceData.CounterpartyBankAccount,
				IsNewDocument);
		EndIf;

		SetProperty(
			ObjectOfDocument,
			"Counterparty",
			SourceData.Counterparty,
			IsNewDocument);

	EndIf;
	
	If SourceData.OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements
		Or SourceData.OperationKind = Enums.OperationTypesPaymentExpense.Vendor
		Or SourceData.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer Then
	
		GLAccountsInDocuments.FillGLAccountsInDocument(ObjectOfDocument);
		
	EndIf;
	
EndProcedure

Procedure FillAttributesPaymentReceipt(ObjectOfDocument, SourceData, IsNewDocument)
	
	SetProperty(
		ObjectOfDocument,
		"Date",
		SourceData.Received,
		IsNewDocument);
	
	SetProperty(
		ObjectOfDocument,
		"OperationKind",
		SourceData.OperationKind,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"Company",
		SourceData.Company,
		IsNewDocument);
	
	SetProperty(
		ObjectOfDocument,
		"BankAccount",
		SourceData.BankAccount,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"CashCurrency",
		SourceData.BankAccount.CashCurrency,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"Item",
		SourceData.CFItem,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"DocumentAmount",
		SourceData.Amount,
		IsNewDocument,
		True);
	
	SetProperty(
		ObjectOfDocument,
		"ExternalDocumentNumber",
		SourceData.ExternalDocumentNumber,
		IsNewDocument);
	
	SetProperty(
		ObjectOfDocument,
		"ExternalDocumentDate",
		SourceData.ExternalDocumentDate,
		IsNewDocument);
	
	If IsNewDocument Then
		
		ObjectOfDocument.SetNewNumber();
		
		If ObjectOfDocument.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
			ObjectOfDocument.VATTaxation = DriveServer.VATTaxation(SourceData.Company, SourceData.Received);
		Else
			ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
		EndIf;
		
	EndIf;
	
	// Filling document tabular section.
	If SourceData.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer
		Or SourceData.OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor
		Or SourceData.OperationKind = Enums.OperationTypesPaymentReceipt.PaymentFromThirdParties
		Or SourceData.OperationKind = Enums.OperationTypesPaymentReceipt.PayoutFromPaymentProcessor
		Or SourceData.OperationKind = Enums.OperationTypesPaymentReceipt.OtherSettlements Then
		
		If TypeOf(SourceData.CounterpartyBankAccount) <> Type("String") Then
			SetProperty(
				ObjectOfDocument,
				"CounterpartyAccount",
				SourceData.CounterpartyBankAccount,
				IsNewDocument);
		EndIf;
		
		SetProperty(
			ObjectOfDocument,
			"Counterparty",
			SourceData.Counterparty,
			IsNewDocument);
		
		If ObjectOfDocument.PaymentDetails.Count() = 0 Then
			RowOfDetails = ObjectOfDocument.PaymentDetails.Add();
		Else
			RowOfDetails = ObjectOfDocument.PaymentDetails[0];
		EndIf;
		
		OneRowInDecipheringPayment = ObjectOfDocument.PaymentDetails.Count() = 1;
		
		SetProperty(
			RowOfDetails,
			"Contract",
			SourceData.Contract,
			IsNewDocument);
			
		If SourceData.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer
			Or SourceData.OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor Then
			
			SetProperty(
				RowOfDetails,
				"AdvanceFlag",
				SourceData.AdvanceFlag,
				IsNewDocument,
				True);
		EndIf;
		
		SetProperty(
			RowOfDetails,
			"Item",
			SourceData.CFItem,
			IsNewDocument);
			
		// Filling document tabular section.
		If IsNewDocument
			Or OneRowInDecipheringPayment
				And RowOfDetails.PaymentAmount <> ObjectOfDocument.DocumentAmount Then
			
			RowOfDetails.PaymentAmount	= ObjectOfDocument.DocumentAmount;
			DateOfFilling				= ObjectOfDocument.Date;
			SettlementsCurrency			= RowOfDetails.Contract.SettlementsCurrency;
			
			CalculateRateAndAmountOfAccounts(
				RowOfDetails,
				SettlementsCurrency,
				DateOfFilling,
				ObjectOfDocument,
				IsNewDocument);
			
			If RowOfDetails.ExchangeRate = 0 Then
				
				SetProperty(
					RowOfDetails,
					"ExchangeRate",
					1,
					IsNewDocument);
				
				SetProperty(
					RowOfDetails,
					"Multiplicity",
					1,
					IsNewDocument);
				
				SetProperty(
					RowOfDetails,
					"SettlementsAmount",
					RowOfDetails.PaymentAmount,
					IsNewDocument);
				
			EndIf;
			
			If ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
				
				DefaultVATRate	= InformationRegisters.AccountingPolicy.GetDefaultVATRate(ObjectOfDocument.Date, ObjectOfDocument.Company);
				VATRateValue	= DriveReUse.GetVATRateValue(DefaultVATRate);
				
				RowOfDetails.VATRate	= DefaultVATRate;
				RowOfDetails.VATAmount	= RowOfDetails.PaymentAmount - (RowOfDetails.PaymentAmount) / ((VATRateValue + 100) / 100);
				
			Else
				
				If ObjectOfDocument.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
					DefaultVATRate = Catalogs.VATRates.Exempt;
				Else
					DefaultVATRate = Catalogs.VATRates.ZeroRate;
				EndIf;
				
				RowOfDetails.VATRate	= DefaultVATRate;
				RowOfDetails.VATAmount	= 0;
				
			EndIf;
			
		EndIf;
		
	ElsIf SourceData.OperationKind = Enums.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty
		Or SourceData.OperationKind = Enums.OperationTypesPaymentReceipt.LoanSettlements 
		Or SourceData.OperationKind = Enums.OperationTypesPaymentReceipt.Taxes
		Or SourceData.OperationKind = Enums.OperationTypesPaymentReceipt.Other Then
		
		If TypeOf(SourceData.CounterpartyBankAccount) <> Type("String") Then
			SetProperty(
				ObjectOfDocument,
				"CounterpartyAccount",
				SourceData.CounterpartyBankAccount,
				IsNewDocument);
		EndIf;
		
		SetProperty(
			ObjectOfDocument,
			"Counterparty",
			SourceData.Counterparty,
			IsNewDocument);

	EndIf;
	
	If SourceData.OperationKind = Enums.OperationTypesPaymentReceipt.PaymentFromThirdParties
		Or SourceData.OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor
		Or SourceData.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
	
		GLAccountsInDocuments.FillGLAccountsInDocument(ObjectOfDocument);
		
	EndIf;
	
EndProcedure

Procedure WriteObject(ObjectToWrite, SectionRow, IsNewDocument, AutomaticallyFillInDebts, ResultStructure, Counter)
	
	DocumentType = ObjectToWrite.Metadata().Name;
	If DocumentType = "PaymentExpense"
		AND AutomaticallyFillInDebts
		AND SectionRow.OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
		DriveServer.FillPaymentDetailsExpense(ObjectToWrite,,,,, SectionRow.Contract);
	ElsIf DocumentType = "PaymentReceipt"
		AND AutomaticallyFillInDebts
		AND SectionRow.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer Then
		DriveServer.FillPaymentDetailsReceipt(ObjectToWrite,,,,, SectionRow.Contract);
	EndIf;
	
	SetProperty(
		ObjectToWrite,
		"PaymentPurpose",
		SectionRow.PaymentPurpose,
		IsNewDocument,
		False);
		
	SetProperty(
		ObjectToWrite,
		"Author",
		Users.CurrentUser(),
		IsNewDocument,
		True);
		
	If ValueIsFilled(SectionRow.ExpenseGLAccount) Then
		SetProperty(
			ObjectToWrite,
			"Correspondence",
			SectionRow.ExpenseGLAccount,
			IsNewDocument);
	EndIf;
		
	ObjectModified	= ObjectToWrite.Modified();
	ObjectPosted	= ObjectToWrite.Posted;
	NameObject		= GetObjectPresentation(ObjectToWrite);
	
	If ObjectModified Then
		
		Try
			
			If ObjectPosted Then
				ObjectToWrite.Write(DocumentWriteMode.UndoPosting);
			Else
				ObjectToWrite.Write(DocumentWriteMode.Write);
			EndIf;
			
			Counter = Counter + 1;
			
		Except
			
			CommonClientServer.AddUserError(
				ResultStructure.Errors,
				"Object.Import[%1].Document",
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = '%1 %2. Errors occurred while writing.'; ru = '%1 %2. ?????????????????? ???????????? ?????? ????????????!';pl = '%1 %2. Podczas zapisu zaistnia??y b????dy.';es_ES = '%1 %2. Errores ocurridos al grabar.';es_CO = '%1 %2. Errores ocurridos al grabar.';tr = '%1 %2. Yazma s??ras??nda hata olu??tu.';it = '%1 %2. Si sono verificati errori durante la scrittura.';de = '%1 %2. Beim Schreiben sind Fehler aufgetreten.'"),
					NameObject,
					?(ObjectToWrite.IsNew(),
						NStr("en = 'not created'; ru = '???? ????????????';pl = 'nie utworzono';es_ES = 'no creado';es_CO = 'no creado';tr = 'olu??turulmad??';it = 'non creato';de = 'nicht erstellt'"), 
						NStr("en = 'not written'; ru = '???? ??????????????';pl = 'nie zapisano';es_ES = 'no grabado';es_CO = 'no grabado';tr = 'yaz??lmad??';it = 'non registrato';de = 'nicht geschrieben'"))),
				"",
				SectionRow.LineNumber);
			Return;
			
		EndTry;
		
	Else
		CommonClientServer.AddUserError(
			ResultStructure.Errors,
			"Object.Import[%1].Document",
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 already exists. Import have been performed earlier.'; ru = '%1 ?????? ????????????????????. ???????????????? ?????????????????????????? ??????????.';pl = '%1 ju?? istnieje. Import m??g?? zosta?? wykonany wcze??niej.';es_ES = '%1 ya existe. Importaci??n de ha realizado antes.';es_CO = '%1 ya existe. Importaci??n de ha realizado antes.';tr = '%1 ??nceden mevcuttur. ????e aktarma ??nceden ger??ekle??tirildi.';it = '%1 gi?? esiste. L''importazione ?? stata effettuata in precedenza.';de = '%1 existiert bereits. Der Import wurde fr??her durchgef??hrt.'"),
				NameObject),
			"",
			SectionRow.LineNumber);
	EndIf;
	
EndProcedure

#EndRegion

// Returns a list of permissions required to import a bank classifier.
//
// Returns:
//  An array.
//
Function Permissions()
	
	Permissions = New Array;
	DataProcessorName = "ImportBankClassifier";
	If Metadata.DataProcessors.Find(DataProcessorName) <> Undefined Then
		DataProcessors[DataProcessorName].AddPermissions(Permissions);
	EndIf;
	
	Return Permissions;
	
EndFunction

// Determines whether classifier data update is required.
//
Function ClassifierUpToDate() Export
	LatestUpdate = LastImportDate();
	AllowedExpiration = 60*60*24;
	
	If CurrentSessionDate() > LatestUpdate + AllowedExpiration Then
		Return False; // Expiration started.
	EndIf;
	
	Return True;
EndFunction

// Returns name of external data processor BankClassifierImportProcessor
//
Function GetBankClassifierImportProcessor() Export
	 	
	ExtDataProcessor = Constants.BankClassifierImportProcessor.Get();
	
	If Not GetFunctionalOption("UseAdditionalReportsAndDataProcessors") Then	
		Raise NStr("en = 'Functional option ""Use additional reports and data processors"" is disabled. 
		           |Enable option in the Settings > Print forms, reports and data processors > Additional reports and data processors'; 
		           |ru = '???????????????????????????? ?????????? ""???????????????????????? ???????????????????????????? ???????????? ?? ??????????????????"" ??????????????????.
		           |???????????????? ?????????? ?????????? ?? ?????????????? ?????????????????? > ???????????????? ??????????, ???????????? ?? ?????????????????? > ???????????????????????????? ???????????? ?? ??????????????????'; 
		           |pl = 'Opcja funkcjonalna ""U??yj dodatkowych raport??w i procesor??w danych"" jest wy????czona. 
		           |W????cz opcj?? w Ustawienia> Formularz wydruku, raporty i procesory danych> Dodatkowe raporty i procesory danych';
		           |es_ES = 'La opci??n funcional ""Utilizar informes y procesadores de datos adicionales"" est?? desactivada. 
		           |Habilite la opci??n en Configuraci??n > Imprimir formularios, informes y procesadores de datos > Informes y procesadores de datos adicionales';
		           |es_CO = 'La opci??n funcional ""Utilizar informes y procesadores de datos adicionales"" est?? desactivada. 
		           |Habilite la opci??n en Configuraci??n > Imprimir formularios, informes y procesadores de datos > Informes y procesadores de datos adicionales';
		           |tr = '????levsel se??enek ""Ek raporlar ve veri i??lemcileri kullan"" devre d?????? b??rak??ld??. 
		           |Ayarlar> Formlar??, raporlar?? ve veri i??lemcileri yazd??r> Ek raporlar ve veri i??lemcileri se??ene??ini etkinle??tirin';
		           |it = 'L''opzione funzionale ""Utilizza report ed elaboratori dati aggiuntivi"" ?? disabilitata.
		           |Abilitare l''opzione in Impostazioni->Moduli di stampa, reports ed elaboratori dati->Report e elaboratori dati aggiuntivi';
		           |de = 'Die funktionale Option ""Zus??tzliche Berichte und Datenverarbeiter verwenden"" ist deaktiviert.
		           |Aktivieren Sie die Option in den Einstellungen > Druckformulare, Berichte und Datenverarbeiter > Zus??tzliche Berichte und Datenverarbeiter'");
	EndIf;
	
	If Not ValueIsFilled(ExtDataProcessor) Then	
		Raise NStr("en = 'Bank classifier import processor is not set. 
                    |You can configure it in the Settings > Others > Configure classifier import'; ru = '?????????????????? ???????????????? ???????????????????????????? ???????????? ???? ????????????.
                    |?????????????? ?????????????????? ?????????? ?? ?????????????? ?????????????????? > ???????????? > ?????????????????? ???????????????? ????????????????????????????'; 
                    |pl = 'Opracowanie do importu klasyfikatora bankowego nie jest ustawione.
                    |Mo??esz go skonfigurowa?? w sekcji Ustawienia> Inne> Konfiguruj import klasyfikatora';
                    |es_ES = 'Procesador de la importaci??n del clasificador de bancos no est?? establecido. 
                    | Puede configurarlo en Configuraci??n > Otros > Configurar la importaci??n del clasificador.';
                    |es_CO = 'Procesador de la importaci??n del clasificador de bancos no est?? establecido. 
                    | Puede configurarlo en Configuraci??n > Otros > Configurar la importaci??n del clasificador.';
                    |tr = 'Banka s??n??fland??r??c?? i??e aktarma i??lemcisi ayarl?? de??ildir.
                    |Bunu Ayarlar - Destek ve hizmet - S??n??fland??r??c?? b??l??m??nde yap??land??rabilirsiniz';
                    |it = 'L''importazione del classificatore Banche non ?? impostata.
                    |Potete configurarla nelle impostazioni.';
                    |de = 'Der Importprozessor des Bankklassifikators ist nicht gesetzt.
                    |Sie k??nnen es konfigurieren, indem Sie Einstellungen > Andere > Klassifikatorimport konfigurieren.'");
	EndIf;
	
	Return AdditionalReportsAndDataProcessors.GetExternalDataProcessorsObject(ExtDataProcessor);

EndFunction

Function LastImportDate()
	Return ClassifierInfo().ImportDate;
EndFunction

Function ClassifierInfo()
	SetPrivilegedMode(True);
	Result = Constants.BankClassifierVersion.Get().Get();
	SetPrivilegedMode(False);
	If TypeOf(Result) <> Type("Structure") Then
		Result = NewClassifierDetails();
	EndIf;
	Return Result;
EndFunction

Procedure SetClassifierVersion(Val ClassifierVersion = Undefined)
	If Not ValueIsFilled(ClassifierVersion) Then
		ClassifierVersion = CurrentUniversalDate();
	EndIf;
	ClassifierInfo = NewClassifierDetails(ClassifierVersion, CurrentSessionDate());
	SetPrivilegedMode(True);
	Constants.BankClassifierVersion.Set(New ValueStorage(ClassifierInfo));
	SetPrivilegedMode(False);
EndProcedure

Function NewClassifierDetails(ModificationDate = '00010101', ImportDate = '00010101')
	Result = New Structure;
	Result.Insert("ModificationDate", ModificationDate);
	Result.Insert("ImportDate", ImportDate);
	Return Result;
EndFunction

// Generates and expands text of message to user if classifier data is imported successfully.
// 
// Parameters:
// ClassifierImportParameters - Map:
// Exported						- Number  - Classifier new records quantity.
// Updated						- Number  - Quantity of updated classifier records.
// MessageText					- String - import results message text.
// ImportCompleted               - Boolean - check box of successful classifier data import end.
//
Procedure SupplementMessageText(ClassifierImportParameters)
	
	If IsBlankString(ClassifierImportParameters["MessageText"]) Then
		MessageText = NStr("en = 'The bank classifier was imported successfully.'; ru = '???????????????? ???????????????????????????? ???????????? ?????????????????? ??????????????.';pl = 'Klasyfikator bankowy zosta?? pomy??lnie zaimportowany.';es_ES = 'El clasificador de bancos se ha importado con ??xito.';es_CO = 'El clasificador de bancos se ha importado con ??xito.';tr = 'Banka s??n??fland??r??c??s?? ba??ar??yla i??e aktar??ld??.';it = 'Il classificatore banca ?? stato importato con successo.';de = 'Der Bank-Klassifikator wurde erfolgreich importiert.'");
	Else
		MessageText = ClassifierImportParameters["MessageText"];
	EndIf;
	
	If ClassifierImportParameters["Exported"] > 0 Then
		
		MessageText = MessageText + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'New records: %1.'; ru = '?????????????????? ??????????: %1.';pl = 'Nowe wpisy: %1.';es_ES = 'Nuevos registros: %1.';es_CO = 'Nuevos registros: %1.';tr = 'Yeni kay??tlar: %1.';it = 'Nuove registrazioni: %1.';de = 'Neue Eintr??ge: %1.'"),
			ClassifierImportParameters["Exported"]);
	
	EndIf;
	
	If ClassifierImportParameters["Updated"] > 0 Then
		
		MessageText = MessageText + StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Records updated: %1.'; ru = '?????????????????? ??????????????: %1.';pl = 'Zaktualizowane wpisy: %1.';es_ES = 'Registros actualizados: %1.';es_CO = 'Registros actualizados: %1.';tr = 'Kay??tlar g??ncellendi: %1.';it = 'Registrazioni aggiornate: %1.';de = 'Eintr??ge aktualisiert: %1.'"),
		ClassifierImportParameters["Updated"]);

	EndIf;
	
	ClassifierImportParameters.Insert("MessageText", MessageText);
	
EndProcedure

#EndRegion
