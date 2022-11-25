
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - form attribute initialization,
// - set parameters of the functional form
// options,
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed);
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	GenerateAccountingSectionsList();
	
	DocumentObject = FormAttributeToValue("Object");
	If DocumentObject.IsNew() 
		And Parameters.Property("BasisDocument") 
		And ValueIsFilled(Parameters.BasisDocument) Then
		DocumentObject.Fill(Parameters.BasisDocument);
		ValueToFormAttribute(DocumentObject, "Object");
	EndIf;
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	Cash = Enums.CashAssetTypes.Cash;	
	ParentCompany = DriveServer.GetCompany(Object.Company);	
	CurrencyByDefault = Constants.FunctionalCurrency.Get();
	
	If Not Constants.UseSecondaryEmployment.Get() Then
		If Items.Find("PayrollEmployeeCode") <> Undefined Then
			Items.PayrollEmployeeCode.Visible = False;
		EndIf;
		If Items.Find("SettlementsWithAdvanceHoldersEmployeeCode") <> Undefined Then
			Items.SettlementsWithAdvanceHoldersEmployeeCode.Visible = False;
		EndIf;
	EndIf;
	
	User = Users.CurrentUser();
	MainWarehouse = DriveReUse.GetValueByDefaultUser(User, "MainWarehouse", Catalogs.BusinessUnits.MainWarehouse);
	MainDepartment = DriveReUse.GetValueByDefaultUser(User, "MainDepartment", Catalogs.BusinessUnits.MainDepartment);
	
	DefaultExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DepreciationCharge");
	
	FillDocumentTypeLists();
	UpdateInventoryDocumentTypeChoiceList();
	ReadDocumentTypes();
	
	FillCashAssetsTables();
	SetCashAssetsAmountTitles();
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAccountsReceivable", True);
	ParametersStructure.Insert("FillAccountsPayable", True);
	ParametersStructure.Insert("FillFixedAssets", True);
	
	FillAddedColumns(ParametersStructure);
	
	IncomeAndExpenseItemsInDocuments.SetRegistrationAttributesVisibility(ThisObject, "FixedAssetsRegisterDepreciationCharge");
	
	SetFormConditionalAppearance();
	
	Items.GLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.InventoryGLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.AccountsPayableGLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.AccountsReceivableGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	ProcessingCompanyVATNumbers();
	
	// Filling in the additional attributes of tabular section.
	SetAccountsAttributesVisible(, , "AccountsPayable");
	SetAccountsAttributesVisible(, , "AccountsReceivable");
	
	// FO Use Production subsystem.
	SetVisibleByFOUseProductionSubsystem();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.OpeningBalanceEntry.TabularSections.Inventory, DataLoadSettings, ThisObject, False);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	Items.InventoryImportDataFromExternalSourceInventory.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	SetCurrentPage();
	SetItemsVisibleEnabled();
	SetAutogenerationFieldsVisible();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAccountsReceivable", True);
	ParametersStructure.Insert("FillAccountsPayable", True);
	ParametersStructure.Insert("FillFixedAssets", True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	EndIf;
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" Then
		If ValueIsFilled(Parameter) Then
			For Each CurRow In Object.AccountsReceivable Do
				If Parameter = CurRow.Counterparty Then
					SetAccountsAttributesVisible(, , "AccountsReceivable");
					Return;
				EndIf;
			EndDo;
			For Each CurRow In Object.AccountsPayable Do
				If Parameter = CurRow.Counterparty Then
					SetAccountsAttributesVisible(, , "AccountsPayable");
					Return;
				EndIf;
			EndDo;
		EndIf;
	ElsIf EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Object.Autogeneration Then
		
		TabSections = New Array;
		TabSections.Add("AccountsReceivable");
		TabSections.Add("AccountsPayable");
		TabSections.Add("AdvanceHolders");
		
		MessageText = NStr("en = 'The ""Type"" of the billing document is required on line %1 of the ""%2"" list.'; ru = 'Укажите ""Тип"" документа расчета В строке %1 списка ""%2"".';pl = '""Typ"" dokumentu rozliczeniowego jest wymagany w wierszu %1 listy ""%2"".';es_ES = 'El ""Tipo"" del documento de facturación se requiere en la línea %1 de la lista ""%2"".';es_CO = 'El ""Tipo"" del documento de facturación se requiere en la línea %1 de la lista ""%2"".';tr = '""%2"" listesinin %1 satırında fatura belgesinin ""Türü"" zorunlu.';it = 'Il ""Tipo"" del documento di fatturazione è richiesto nella riga %1 dell''elenco ""%2"".';de = 'Der ""Typ"" des Abrechnungsbelegs wird in Zeile %1 der Liste ""%2"" benötigt.'");
		
		FillCheckDocumentType(TabSections, MessageText, Cancel);
		
	EndIf;
	
	If Object.InventoryValuationMethod = Enums.InventoryValuationMethods.FIFO Then
		
		If Object.AutogenerateInventoryAcqusitionDocuments Then
			
			TabSections = New Array;
			TabSections.Add("Inventory");
			
			MessageText = NStr("en = 'The ""Type"" of the acqusition document is required on line %1 of the ""%2"" list.'; ru = 'Укажите ""Тип"" документа приобретения в строке %1 списка ""%2"".';pl = '""Typ"" dokumentu zakupu jest wymagany w wierszu %1 listy ""%2"".';es_ES = 'El ""Tipo"" del documento de adquisición se requiere en la línea %1 de la lista ""%2"".';es_CO = 'El ""Tipo"" del documento de adquisición se requiere en la línea %1 de la lista ""%2"".';tr = '""%2"" listesinin %1 satırında alım belgesinin ""Tür""ü zorunlu.';it = 'Il ""Tipo"" del documento di acquisizione è richiesto nella riga %1 dell''elenco ""%2"".';de = 'Der ""Typ"" des Einkaufsbelegs wird in Zeile %1 der Liste ""%2"" benötigt.'");
			
			FillCheckDocumentType(TabSections, MessageText, Cancel);
			
		Else
			
			OpeningBalanceEntryName = Metadata.Documents.OpeningBalanceEntry.Name;
			
			For Each InventoryRow In Object.Inventory Do
				
				If ValueIsFilled(InventoryRow.DocumentType)
					And Not InventoryRow.DocumentType = OpeningBalanceEntryName
					And Not ValueIsFilled(InventoryRow.Document) Then
					
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'The ""Document"" is required on line %1 of the ""Inventory"" list.'; ru = 'В строке %1 списка ""ТМЦ"" необходимо указать ""Документ"".';pl = '""Dokument"" jest wymagany w wierszu %1 listy ""Zapasy"".';es_ES = 'El ""Documento"" se requiere en la línea%1 de la lista de ""Inventario"".';es_CO = 'El ""Documento"" se requiere en la línea%1 de la lista de ""Inventario"".';tr = '""Stok"" listesinin %1 satırında ""Belge"" gerekli.';it = 'Il ""Documento"" è richiesto nella riga %1 dell''elenco ""Scorte"".';de = 'Das ""Dokument"" ist in der Zeile %1 der Liste ""Bestand"" erforderlich.'"), 
						InventoryRow.LineNumber);
						
					MessageField = CommonClientServer.PathToTabularSection("Object.Inventory", InventoryRow.LineNumber, "Document");
					CommonClientServer.MessageToUser(MessageText, , MessageField, , Cancel);
				
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Object.Autogeneration Then
		
		TableNames = New Array;
		TableNames.Add("AccountsReceivable");
		TableNames.Add("AccountsPayable");
		TableNames.Add("AdvanceHolders");
		
		FillDocumentEmptyRef(TableNames);	
		
	EndIf;
	
	If Object.AutogenerateInventoryAcqusitionDocuments Then
		
		TableNames = New Array;
		TableNames.Add("Inventory");
		
		FillDocumentEmptyRef(TableNames);
		
	EndIf;
	
	Object.CashAssets.Clear();
	For Each CurRow In CashAssetsBank Do
		FillPropertyValues(Object.CashAssets.Add(), CurRow);
	EndDo;
	For Each CurRow In CashAssetsCash Do
		FillPropertyValues(Object.CashAssets.Add(), CurRow);
	EndDo;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved do
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Procedure generates selection list for the accounting section.
//
&AtServer
Procedure GenerateAccountingSectionsList()
	
	// FO Use Payroll subsystem.
	If Constants.UsePayrollSubsystem.Get()
		OR Object.AccountingSection = Enums.OpeningBalanceAccountingSections.Payroll Then
		
		Items.AccountingSection.ChoiceList.Add(Enums.OpeningBalanceAccountingSections.Payroll);
		
	EndIf;
	
	// FD Use Belongings.
	If Constants.UseFixedAssets.Get()
		OR Object.AccountingSection = Enums.OpeningBalanceAccountingSections.FixedAssets Then
		
		Items.AccountingSection.ChoiceList.Add(Enums.OpeningBalanceAccountingSections.FixedAssets);
		
	EndIf;
	
	// Other.
	If UseDefaultTypeOfAccounting Then
		Items.AccountingSection.ChoiceList.Add(Enums.OpeningBalanceAccountingSections.Other);
	EndIf;
	
EndProcedure

// Function receives page name for the document accounting section.
//
// Parameters:
// AccountingSection - EnumRef.OpeningBalanceAccountingSections - Accounting section
//
// Returns:
// String - Page name corresponding to the accounting sections
//
&AtClient
Function GetPageName(AccountingSection)
	
	Map = GetPageMap();
	
	PageName = Map.Get(AccountingSection);
	
	Return PageName;
	
EndFunction

&AtServer
Function GetPageMap()
	
	Map = New Map;
	Map.Insert(Enums.OpeningBalanceAccountingSections.FixedAssets, "FolderFixedAssets");
	Map.Insert(Enums.OpeningBalanceAccountingSections.Inventory, "GroupInventory");
	Map.Insert(Enums.OpeningBalanceAccountingSections.CashAssets, "FolderBanking");
	Map.Insert(Enums.OpeningBalanceAccountingSections.AccountsReceivablePayable, "GroupSettlementsWithCounterparties");
	Map.Insert(Enums.OpeningBalanceAccountingSections.Taxes, "FolderTaxesSettlements");
	Map.Insert(Enums.OpeningBalanceAccountingSections.Payroll, "GroupSettlementsWithHPersonnel");
	Map.Insert(Enums.OpeningBalanceAccountingSections.AdvanceHolders, "GroupAdvanceHolders");
	Map.Insert(Enums.OpeningBalanceAccountingSections.Other, "GroupOtherSections");
	
	Return Map;
	
EndFunction

// Procedure sets the current page depending on the accounting section.
//
&AtClient
Procedure SetCurrentPage()
	
	Item = Items.Find(GetPageName(Object.AccountingSection));
	
	If Item <> Undefined Then
		Items.Pages.CurrentPage = Item;
	EndIf;
	
EndProcedure

// Procedure sets items visible and availability.
//
&AtClient
Procedure SetItemsVisibleEnabled()
	
	If Object.AccountingSection = PredefinedValue("Enum.OpeningBalanceAccountingSections.AccountsReceivablePayable")
		OR Object.AccountingSection = PredefinedValue("Enum.OpeningBalanceAccountingSections.AdvanceHolders") Then
		
		Items.Autogeneration.Visible = True;	
		
	Else
		
		Items.Autogeneration.Visible = False;
		Object.Autogeneration = False;
		
	EndIf;
	
	If Object.AccountingSection = PredefinedValue("Enum.OpeningBalanceAccountingSections.Inventory")
		And Object.InventoryValuationMethod = PredefinedValue("Enum.InventoryValuationMethods.FIFO") Then
			
		Items.AutogenerateInventoryAcqusitionDocuments.Visible = True;
		Items.InventoryGroupDocument.Visible = True;
		
	Else
		
		Items.AutogenerateInventoryAcqusitionDocuments.Visible = False;
		Items.InventoryGroupDocument.Visible = False;
		Object.AutogenerateInventoryAcqusitionDocuments = False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetFormConditionalAppearance()
	
	Text = StringFunctionsClientServer.SubstituteParametersToString("<%1>",
		NStr("en = 'generated automatically'; ru = 'создано автоматически';pl = 'wygenerowano automatycznie';es_ES = 'generado automáticamente';es_CO = 'generado automáticamente';tr = 'otomatik oluşturuldu';it = 'generato automaticamente';de = 'automatisch generiert'"));
		
	// InventoryDocument InventoryDocumentType
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AutogenerateInventoryAcqusitionDocuments",
		True,
		DataCompositionComparisonType.Equal);
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.Inventory.Document",
		Undefined,
		DataCompositionComparisonType.NotFilled);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "InventoryDocument");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AutogenerateInventoryAcqusitionDocuments",
		False,
		DataCompositionComparisonType.Equal);
		
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.Inventory.Document",
		Undefined,
		DataCompositionComparisonType.NotFilled);
		
	NewConditionalAppearanceFilterGroup = WorkWithForm.CreateFilterItemGroup(
		NewConditionalAppearance.Filter, DataCompositionFilterItemsGroupType.OrGroup);
		
	WorkWithForm.AddFilterItem(NewConditionalAppearanceFilterGroup,
		"Object.Inventory.DocumentType",
		Metadata.Documents.OpeningBalanceEntry.Name,
		DataCompositionComparisonType.Equal);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "InventoryDocument");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", NStr("en = '<this document>'; ru = '<этот документ>';pl = '<ten dokument>';es_ES = '<este documento>';es_CO = '<este documento>';tr = '<bu belge>';it = '<questo documento>';de = '<dieses Dokument>'"));
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	NewConditionalAppearanceFilterGroup = WorkWithForm.CreateFilterItemGroup(
		NewConditionalAppearance.Filter, DataCompositionFilterItemsGroupType.OrGroup);
		
	WorkWithForm.AddFilterItem(NewConditionalAppearanceFilterGroup,
		"Object.Inventory.Document",
		Object.Ref,
		DataCompositionComparisonType.Equal);
		
	WorkWithForm.AddFilterItem(NewConditionalAppearanceFilterGroup,
		"Object.Inventory.DocumentType",
		Metadata.Documents.OpeningBalanceEntry.Name,
		DataCompositionComparisonType.Equal);
		
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "InventoryDocument");
	
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AutogenerateInventoryAcqusitionDocuments",
		False,
		DataCompositionComparisonType.Equal);
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.Inventory.DocumentType",
		Undefined,
		DataCompositionComparisonType.Filled);
		
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.Inventory.Document",
		Undefined,
		DataCompositionComparisonType.NotFilled);
		
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.Inventory.DocumentType",
		Metadata.Documents.OpeningBalanceEntry.Name,
		DataCompositionComparisonType.NotEqual);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "InventoryDocument");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", True);
	
	// AccountsReceivableDocument
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.Autogeneration",
		True,
		DataCompositionComparisonType.Equal);
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AccountsReceivable.Document",
		,
		DataCompositionComparisonType.NotFilled);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "AccountsReceivableDocument");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	
	// SettlementsWithAdvanceHoldersDocument
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.Autogeneration",
		True,
		DataCompositionComparisonType.Equal);
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AdvanceHolders.Document",
		,
		DataCompositionComparisonType.NotFilled);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "SettlementsWithAdvanceHoldersDocument");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	
	// AccountsPayableDocument
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.Autogeneration",
		True,
		DataCompositionComparisonType.Equal);
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AccountsPayable.Document",
		,
		DataCompositionComparisonType.NotFilled);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "AccountsPayableDocument");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	
	// AccountsReceivableSalesOrder
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AccountsReceivable.Counterparty",
		,
		DataCompositionComparisonType.Filled);
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AccountsReceivable.DoOperationsByOrders",
		False,
		DataCompositionComparisonType.Equal);
	
	Text = StringFunctionsClientServer.SubstituteParametersToString("<%1>",
		NStr("en = 'Billing details by orders are not specified for the counterparty'; ru = 'Для контрагента не установлены расчеты по заказам';pl = 'Dane rozliczeniowe według zamówień nie są określone dla kontrahenta';es_ES = 'Los detalles del presupuesto por órdenes no están especificados para la contraparte';es_CO = 'Los detalles del presupuesto por órdenes no están especificados para la contraparte';tr = 'Cari hesap için siparişlere göre fatura ayrıntıları belirtilmemiş';it = 'I dettagli di fatturazione per ordini non sono specificati per la controparte';de = 'Abrechnungsdetails nach Aufträgen sind für die Geschäftspartner nicht angegeben'"));
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "AccountsReceivableSalesOrder");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// AccountsReceivableQuote
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AccountsReceivable.Counterparty",
		,
		DataCompositionComparisonType.Filled);
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AccountsReceivable.TrackPaymentsByBills",
		False,
		DataCompositionComparisonType.Equal);
	
	Text = StringFunctionsClientServer.SubstituteParametersToString("<%1>",
		NStr("en = 'payments are not accounted for the counterparty'; ru = 'для контрагента не учтены платежи';pl = 'płatności nie są rozliczane dla kontrahenta';es_ES = 'los pagos no se contabilizan para la contrapartida';es_CO = 'los pagos no se contabilizan para la contrapartida';tr = 'cari hesap için ödemeler muhasebeleştirilmez';it = 'i pagamento non sono contabilizzati per la controparte';de = 'Zahlungen sind nicht für die Geschäftspartner verbucht'"));
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "AccountsReceivableQuote");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// AccountsReceivableAgreement
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AccountsReceivable.Counterparty",
		,
		DataCompositionComparisonType.Filled);
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AccountsReceivable.DoOperationsByContracts",
		False,
		DataCompositionComparisonType.Equal);
	
	Text = StringFunctionsClientServer.SubstituteParametersToString("<%1>",
		NStr("en = 'Billing details by contracts are not specified for the counterparty'; ru = 'Для контрагента не установлены расчеты по договорам';pl = 'Dane rozliczeniowe według kontraktów nie są określone dla kontrahenta';es_ES = 'Los detalles del presupuesto no están especificados para la contraparte';es_CO = 'Los detalles del presupuesto no están especificados para la contraparte';tr = 'Cari hesap için sözleşmelerle fatura detayları belirtilmemiştir';it = 'I dettagli di fatturazione per contratti non sono specificati per la controparte';de = 'Abrechnungsdetails nach Verträgen sind für die Geschäftspartner nicht angegeben'"));
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "AccountsReceivableAgreement");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// AccountsPayablePurchaseOrder
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AccountsPayable.Counterparty",
		,
		DataCompositionComparisonType.Filled);
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AccountsPayable.DoOperationsByOrders",
		False,
		DataCompositionComparisonType.Equal);
	
	Text = StringFunctionsClientServer.SubstituteParametersToString("<%1>",
		NStr("en = 'Billing details by orders are not specified for the counterparty'; ru = 'Для контрагента не установлены расчеты по заказам';pl = 'Dane rozliczeniowe według zamówień nie są określone dla kontrahenta';es_ES = 'Los detalles del presupuesto por órdenes no están especificados para la contraparte';es_CO = 'Los detalles del presupuesto por órdenes no están especificados para la contraparte';tr = 'Cari hesap için siparişlere göre fatura ayrıntıları belirtilmemiş';it = 'I dettagli di fatturazione per ordini non sono specificati per la controparte';de = 'Abrechnungsdetails nach Aufträgen sind für die Geschäftspartner nicht angegeben'"));
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "AccountsPayablePurchaseOrder");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// AccountsPayableQuote
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AccountsPayable.Counterparty",
		,
		DataCompositionComparisonType.Filled);
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AccountsPayable.TrackPaymentsByBills",
		False,
		DataCompositionComparisonType.Equal);
	
	Text = StringFunctionsClientServer.SubstituteParametersToString("<%1>",
		NStr("en = 'payments are not accounted for the counterparty'; ru = 'для контрагента не учтены платежи';pl = 'płatności nie są rozliczane dla kontrahenta';es_ES = 'los pagos no se contabilizan para la contrapartida';es_CO = 'los pagos no se contabilizan para la contrapartida';tr = 'cari hesap için ödemeler muhasebeleştirilmez';it = 'i pagamento non sono contabilizzati per la controparte';de = 'Zahlungen sind nicht für die Geschäftspartner verbucht'"));
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "AccountsPayableQuote");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// AccountsPayableContract
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AccountsPayable.Counterparty",
		,
		DataCompositionComparisonType.Filled);
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AccountsPayable.DoOperationsByContracts",
		False,
		DataCompositionComparisonType.Equal);
	
	Text = StringFunctionsClientServer.SubstituteParametersToString("<%1>",
		NStr("en = 'Billing details by contracts are not specified for the counterparty'; ru = 'Для контрагента не установлены расчеты по договорам';pl = 'Dane rozliczeniowe według kontraktów nie są określone dla kontrahenta';es_ES = 'Los detalles del presupuesto no están especificados para la contraparte';es_CO = 'Los detalles del presupuesto no están especificados para la contraparte';tr = 'Cari hesap için sözleşmelerle fatura detayları belirtilmemiştir';it = 'I dettagli di fatturazione per contratti non sono specificati per la controparte';de = 'Abrechnungsdetails nach Verträgen sind für die Geschäftspartner nicht angegeben'"));
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "AccountsPayableContract");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// StockTransferredToThirdPartiesContract
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.StockTransferredToThirdParties.Counterparty",
		,
		DataCompositionComparisonType.Filled);
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.StockTransferredToThirdParties.DoOperationsByContracts",
		False,
		DataCompositionComparisonType.Equal);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "StockTransferredToThirdPartiesContract");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// StockReceivedFromThirdPartiesContract
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.StockReceivedFromThirdParties.Counterparty",
		,
		DataCompositionComparisonType.Filled);
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.StockReceivedFromThirdParties.DoOperationsByContracts",
		False,
		DataCompositionComparisonType.Equal);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "StockReceivedFromThirdPartiesContract");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.MinorInscriptionText);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", Text);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", False);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// InventoryDocument Type, Number, Date
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.Inventory.Document",
		Undefined,
		DataCompositionComparisonType.Filled);
		
	WorkWithForm.AddAppearanceField(NewConditionalAppearance,
		"InventoryDocumentNumber, InventoryDocumentDate");
	
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// InventoryDocument Type
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AutogenerateInventoryAcqusitionDocuments",
		True,
		DataCompositionComparisonType.Equal);
		
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.Inventory.DocumentType",
		Undefined,
		DataCompositionComparisonType.NotFilled);
		
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "InventoryDocumentType");
	
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", True);
	
	// AccountsPayableDocument Type, Number, Date
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AccountsPayable.Document",
		Undefined,
		DataCompositionComparisonType.Filled);
		
	WorkWithForm.AddAppearanceField(NewConditionalAppearance,
		"AccountsPayableDocumentType, AccountsPayableDocumentNumber, AccountsPayableDocumentDate");
	
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// AccountsReceivableDocument Type, Number, Date
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AccountsReceivable.Document",
		Undefined,
		DataCompositionComparisonType.Filled);
		
	WorkWithForm.AddAppearanceField(NewConditionalAppearance,
		"AccountsReceivableDocumentType, AccountsReceivableDocumentNumber, AccountsReceivableDocumentDate");
	
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// AdvanceHoldersDocument Type, Number, Date
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.AdvanceHolders.Document",
		Undefined,
		DataCompositionComparisonType.Filled);
		
	WorkWithForm.AddAppearanceField(NewConditionalAppearance,
		"AdvanceHoldersDocumentType, AdvanceHoldersDocumentNumber, AdvanceHoldersDocumentDate");
	
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	// Ownership
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance);
	
EndProcedure

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

&AtClientAtServerNoContext
Procedure FillLineNumbers(Table)
	
	LineNumber = 0;
	For Each CurRow In Table Do
		LineNumber = LineNumber + 1;
		CurRow.LineNumber = LineNumber;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillCashAssetsTables()
	
	CashAssetsBank.Clear();
	CashAssetsCash.Clear();
	
	For Each CashAssetsRow In Object.CashAssets Do
		If TypeOf(CashAssetsRow.BankAccountPettyCash) = Type("CatalogRef.BankAccounts") Then
			FillPropertyValues(CashAssetsBank.Add(), CashAssetsRow);
		ElsIf TypeOf(CashAssetsRow.BankAccountPettyCash) = Type("CatalogRef.CashAccounts") Then
			FillPropertyValues(CashAssetsCash.Add(), CashAssetsRow);
		EndIf;
	EndDo;
	FillLineNumbers(CashAssetsBank);
	FillLineNumbers(CashAssetsCash);
	
EndProcedure

&AtClient
Procedure AdjustDocumentType(TabularSectionRow)
	
	If Not IsBlankString(TabularSectionRow.DocumentType) Then
		
		DocTypeDescription = New TypeDescription("DocumentRef." + TabularSectionRow.DocumentType);
		TabularSectionRow.Document = DocTypeDescription.AdjustValue(TabularSectionRow.Document);
		
	Else
		
		TabularSectionRow.Document = Undefined;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetDocumentData(Document)
	
	Result = New Structure;
	
	If ValueIsFilled(Document) Then
		
		DocumentData = Common.ObjectAttributesValues(Document, "Number, Date");
		Result.Insert("DocumentNumber", DocumentData.Number);
		Result.Insert("DocumentDate", DocumentData.Date);
		Result.Insert("DocumentType", Document.Metadata().Name);
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure ReadDocumentTypes()
	
	TableNames = New Array;
	TableNames.Add("Inventory");
	TableNames.Add("AccountsPayable");
	TableNames.Add("AccountsReceivable");
	TableNames.Add("AdvanceHolders");
	
	For Each TableName In TableNames Do
		For Each CurRow In Object[TableName] Do
			If CurRow.Document <> Undefined Then
				CurRow.DocumentType = CurRow.Document.Metadata().Name;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

&AtClient
Procedure SetAutogenerationFieldsVisible()
	
	Items.AccountsPayableDocumentNumber.Visible = Object.Autogeneration;
	Items.AccountsPayableDocumentDate.Visible = Object.Autogeneration;
	
	Items.AccountsReceivableDocumentNumber.Visible = Object.Autogeneration;
	Items.AccountsReceivableDocumentDate.Visible = Object.Autogeneration;
	
	Items.AdvanceHoldersDocumentNumber.Visible = Object.Autogeneration;
	Items.AdvanceHoldersDocumentDate.Visible = Object.Autogeneration;
	
	Items.InventoryDocumentNumber.Visible = Object.AutogenerateInventoryAcqusitionDocuments;
	Items.InventoryDocumentDate.Visible = Object.AutogenerateInventoryAcqusitionDocuments;
	
EndProcedure

&AtServer
Procedure FillDocumentTypeLists()
	
	// begin Drive.FullVersion
	UseProduction = GetFunctionalOption("UseProductionSubsystem");
	// end Drive.FullVersion
	
	AttributesDocument = New Array;
	AttributesDocument.Add("Inventory");
	AttributesDocument.Add("AccountsReceivable");
	AttributesDocument.Add("AccountsPayable");
	AttributesDocument.Add("AdvanceHolders");
	
	DocMetadataTS = Metadata.Documents.OpeningBalanceEntry.TabularSections;
	
	For Each AttributeDocument In AttributesDocument Do
		
		ChoiceList = Items[AttributeDocument + "DocumentType"].ChoiceList;
		AttributeDocumentTypes = DocMetadataTS[AttributeDocument].Attributes.Document.Type.Types();
		
		For Each AttributeDocumentType In AttributeDocumentTypes Do
			
			// begin Drive.FullVersion
			If AttributeDocumentType = Type("DocumentRef.Manufacturing")
				And Not UseProduction Then
				
				Continue;
				
			EndIf;
			// end Drive.FullVersion
			
			DocTypeMetadata = Metadata.FindByType(AttributeDocumentType);
			DocTypeName = DocTypeMetadata.Name;
			DocTypePresentation = DocTypeMetadata.ObjectPresentation;
			If IsBlankString(DocTypePresentation) Then
				DocTypePresentation = DocTypeMetadata.Presentation();
			EndIf;
			
			ChoiceList.Add(DocTypeName, DocTypePresentation);
			
			NewConditionalAppearance = ConditionalAppearance.Items.Add();
			WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
				"Object." + AttributeDocument + ".DocumentType",
				DocTypeName,
				DataCompositionComparisonType.Equal);
			WorkWithForm.AddAppearanceField(NewConditionalAppearance, AttributeDocument + "DocumentType");
			WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Text", DocTypePresentation);
			
		EndDo;
		
	EndDo;
	
EndProcedure

// It receives data set from server for the ContractOnChange procedure.
//
&AtServer
Function GetCompanyDataOnChange(Company)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAccountsReceivable", True);
	ParametersStructure.Insert("FillAccountsPayable", True);
	ParametersStructure.Insert("FillFixedAssets", False);
	
	FillAddedColumns(ParametersStructure);
	
	InventoryValuationMethod = InformationRegisters.AccountingPolicy.InventoryValuationMethod(Object.Date, Company);
	
	StructureData = New Structure();
	StructureData.Insert("Counterparty", DriveServer.GetCompany(Company));
	StructureData.Insert("InventoryValuationMethod", InventoryValuationMethod);
	
	SetCashAssetsAmountTitles();
	
	Return StructureData;
	
EndFunction

Procedure SetCashAssetsAmountTitles()
	
	PresentationCurrency = DriveServer.GetPresentationCurrency(Object.Company);
	AmountPCTitle = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Amount (%1)'; ru = 'Сумма (%1)';pl = 'Wartość (%1)';es_ES = 'Importe (%1)';es_CO = 'Cantidad (%1)';tr = 'Tutar (%1)';it = 'Importo (%1)';de = 'Betrag (%1)'"),
		PresentationCurrency);
	Items.CashAssetsBankAmount.Title = AmountPCTitle;
	Items.CashAssetsCashAmount.Title = AmountPCTitle;
	
EndProcedure

// Receives data set from server for the AccountOnChange procedure.
//
// Parameters:
//  Account         - AccountsChart, account according to which you should receive structure.
//
// Returns:
//  Account structure.
//
&AtServerNoContext
Function GetDataAccountOnChange(Account) Export
	
	StructureData = New Structure();
	
	StructureData.Insert("Currency", Account.Currency);
	
	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServer
Function GetDataFixedAsset(FixedAsset)
	
	StructureData = New Structure();
	StructureData.Insert("MethodOfDepreciationProportionallyProductsAmount", FixedAsset.DepreciationMethod = Enums.FixedAssetDepreciationMethods.ProportionallyToProductsVolume);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillFixedAssets", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAccountsReceivable", True);
	ParametersStructure.Insert("FillAccountsPayable", True);
	
	FillAddedColumns(ParametersStructure);
	
	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Procedure FillDataProductsOnChange(StructureData)
	
	IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	ProductsAttributes = Common.ObjectAttributesValues(StructureData.Products, 
		"MeasurementUnit, VATRate, CountryOfOrigin");
	
	StructureData.Insert("MeasurementUnit", ProductsAttributes.MeasurementUnit);
	StructureData.Insert("VATRate", ProductsAttributes.VATRate);
	StructureData.Insert("CountryOfOrigin", ProductsAttributes.CountryOfOrigin);
	
	If StructureData.Property("PriceKind") Then
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
	Else
		StructureData.Insert("Price", 0);
	EndIf;	
	
	If StructureData.Property("DiscountMarkupKind") 
		AND ValueIsFilled(StructureData.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupPercent", 
			Common.ObjectAttributeValue(StructureData.DiscountMarkupKind, "Percent"));
	Else	
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
		
EndProcedure

// It receives data set from the server for the CashAssetsBankAccountPettyCashOnChange procedure.
//
&AtServerNoContext
Function GetDataCashAssetsBankAccountPettyCashOnChange(BankAccountPettyCash)

	StructureData = New Structure();

	If TypeOf(BankAccountPettyCash) = Type("CatalogRef.CashAccounts") Then
		StructureData.Insert("Currency", BankAccountPettyCash.CurrencyByDefault);
	ElsIf TypeOf(BankAccountPettyCash) = Type("CatalogRef.BankAccounts") Then
		StructureData.Insert("Currency", BankAccountPettyCash.CashCurrency);
	Else
		StructureData.Insert("Currency", Catalogs.Currencies.EmptyRef());
	EndIf;
	
	Return StructureData;
	
EndFunction

// Gets the default contract depending on the billing details.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, TabularSectionName, OperationKind = Undefined)
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company, OperationKind, TabularSectionName);
	
EndFunction

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Procedure FillDataCounterpartyOnChange(StructureData)
	
	Counterparty = StructureData.Counterparty;
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Object.Company, StructureData.TabName);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
	EndIf;
	
	StructureData.Insert(
		"Contract",
		ContractByDefault
	);
	
	StructureData.Insert(
		"SettlementsCurrency",
		ContractByDefault.SettlementsCurrency
	);
	
	StructureData.Insert("DoOperationsByContracts", Counterparty.DoOperationsByContracts);
	StructureData.Insert("DoOperationsByOrders", Counterparty.DoOperationsByOrders);
	
	SetAccountsAttributesVisible(Counterparty.DoOperationsByContracts,
		Counterparty.DoOperationsByOrders,
		StructureData.TabName);
	
EndProcedure

// Procedure sets visible of calculation attributes depending on the parameters specified to the counterparty.
//
&AtServer
Procedure SetAccountsAttributesVisible(Val DoOperationsByContracts = False, Val DoOperationsByOrders = False, TabularSectionName)
	
	FillServiceAttributesByCounterpartyInCollection(Object[TabularSectionName]);
	
	For Each CurRow In Object[TabularSectionName] Do
		If CurRow.DoOperationsByContracts Then
			DoOperationsByContracts = True;
		EndIf;
		If CurRow.DoOperationsByOrders Then
			DoOperationsByOrders = True;
		EndIf;
	EndDo;
	
	If TabularSectionName = "AccountsPayable" Then
		Items.AccountsPayableContract.Visible = DoOperationsByContracts;
		Items.AccountsPayablePurchaseOrder.Visible = DoOperationsByOrders;
	ElsIf TabularSectionName = "AccountsReceivable" Then
		Items.AccountsReceivableAgreement.Visible = DoOperationsByContracts;
		Items.AccountsReceivableSalesOrder.Visible = DoOperationsByOrders;
	EndIf;
	
EndProcedure

// Procedure fills out the service attributes.
//
&AtServerNoContext
Procedure FillServiceAttributesByCounterpartyInCollection(DataCollection)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CAST(Table.LineNumber AS NUMBER) AS LineNumber,
	|	Table.Counterparty AS Counterparty
	|INTO TableOfCounterparty
	|FROM
	|	&DataCollection AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableOfCounterparty.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	TableOfCounterparty.Counterparty.DoOperationsByOrders AS DoOperationsByOrders
	|FROM
	|	TableOfCounterparty AS TableOfCounterparty";
	
	Query.SetParameter("DataCollection", DataCollection.Unload( ,"LineNumber, Counterparty"));
	
	Selection = Query.Execute().Select();
	For Ct = 0 To DataCollection.Count() - 1 Do
		Selection.Next(); // Number of rows in the query selection always equals to the number of rows in the collection
		FillPropertyValues(DataCollection[Ct], Selection, "DoOperationsByContracts, DoOperationsByOrders");
	EndDo;
	
EndProcedure

&AtServer
// It receives data set from server for the ContractOnChange procedure.
//
Procedure FillDataContractOnChange(StructureData)
	
	If UseDefaultTypeOfAccounting And StructureData.Property("GLAccounts") Then
		GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
	EndIf;
	
	StructureData.Insert(
		"SettlementsCurrency",
		StructureData.Contract.SettlementsCurrency
	);
	
EndProcedure

&AtServer
Procedure InventoryStructuralUnitOnChangeAtServer()
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", True);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAccountsReceivable", False);
	ParametersStructure.Insert("FillAccountsPayable", False);
	ParametersStructure.Insert("FillFixedAssets", False);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

// The procedure sets the form attributes
// visible on the option Use subsystem Production.
//
// Parameters:
// No.
//
&AtServer
Procedure SetVisibleByFOUseProductionSubsystem()
	
	// Production.
	If Constants.UseProductionSubsystem.Get() Then
		
		// Setting the method of Business unit selection depending on FO.
		If Not Constants.UseSeveralDepartments.Get()
			AND Not Constants.UseSeveralWarehouses.Get() Then
			
			Items.InventoryStructuralUnit.ListChoiceMode = True;
			If ValueIsFilled(MainWarehouse) Then
				Items.InventoryStructuralUnit.ChoiceList.Add(MainWarehouse);
			EndIf;
			Items.InventoryStructuralUnit.ChoiceList.Add(MainDepartment);
			
		EndIf;
		
	Else
		
		If Constants.UseSeveralWarehouses.Get() Then
			
			NewArray = New Array();
			NewArray.Add(Enums.BusinessUnitsTypes.Warehouse);
			NewArray.Add(Enums.BusinessUnitsTypes.Retail);
			ArrayTypesOfBusinessUnits = New FixedArray(NewArray);
			NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayTypesOfBusinessUnits);
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			
			Items.InventoryStructuralUnit.ChoiceParameters = NewParameters;
			
		Else
			
			Items.InventoryStructuralUnit.Visible = False;
			
		EndIf;
		
		Items.DirectExpencesGroup.Visible = False;
		
	EndIf;
	
EndProcedure

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract, OperationKind, TabularSectionName)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document, OperationKind, TabularSectionName);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Filter = New Structure("ContractKind", Enums.ContractType.WithVendor);
	
	If TabularSectionName = "AccountsReceivable" Then
		Filter.ContractKind = Enums.ContractType.WithCustomer;
	EndIf;
	
	FormParameters.Insert("Filter", Filter);
	
	Return FormParameters;
	
EndFunction

&AtServerNoContext
Function GetCustomerSupplierDocumentsNames(Customer = True)
	
	DocNamesArray = New Array;
	
	If Customer Then
		DocNamesArray.Add(Metadata.Documents.CreditNote.Name);
		DocNamesArray.Add(Metadata.Documents.PaymentReceipt.Name);
		DocNamesArray.Add(Metadata.Documents.CashReceipt.Name);
	Else
		DocNamesArray.Add(Metadata.Documents.DebitNote.Name);
		DocNamesArray.Add(Metadata.Documents.PaymentExpense.Name);
		DocNamesArray.Add(Metadata.Documents.CashVoucher.Name);
	EndIf;
	
	Return DocNamesArray;
	
EndFunction

&AtClient
Procedure ChangeAdvanceFlag(TabularSectionRow, Customer = True)
	
	DocNamesArray = GetCustomerSupplierDocumentsNames(Customer);
	
	DocWithAdvanceFlag = (DocNamesArray.Find(TabularSectionRow.DocumentType) <> Undefined);
	
	If DocWithAdvanceFlag Or DocNamesArray.Find(PreviousDocumentTypeValue) <> Undefined Then
		TabularSectionRow.AdvanceFlag = DocWithAdvanceFlag;
	EndIf;
	
EndProcedure

#Region ProcedureEventHandlersOfHeaderAttributes

// Procedure - OnChange event handler of the document date input field.
// In procedure situation is determined when date change document is
// into document numbering another period and in this case
// assigns to the document new unique number.
//
&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "Attachable_DateChangeProcessing");
	
	DateOnChangeAtServer();
	
EndProcedure

// Procedure - OnChange event handler of the company input field.
// In procedure is executed document
// number clearing and also make parameter set of the form functional options.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	CompanyOnChangeAtServer();
	SetItemsVisibleEnabled();
	
EndProcedure

&AtServer
Procedure CompanyOnChangeAtServer()
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	Object.InventoryValuationMethod = StructureData.InventoryValuationMethod;
	
	ProcessingCompanyVATNumbers(False);
	
EndProcedure

// Procedure - OnChange event handler of the AccountingSection input field.
// Current form page is set in the procedure
// depending on the accounting section.
//
&AtClient
Procedure AccountingSectionOnChange(Item)
	
	// Current form page setting.
	SetCurrentPage();
	SetItemsVisibleEnabled();
	ProcessingCompanyVATNumbers();
	
	Object.FixedAssets.Clear();
	Object.Inventory.Clear();
	Object.DirectCost.Clear();
	Object.CashAssets.Clear();
	CashAssetsBank.Clear();
	CashAssetsCash.Clear();
	Object.AccountsReceivable.Clear();
	Object.AccountsPayable.Clear();
	Object.TaxesSettlements.Clear();
	Object.Payroll.Clear();
	Object.AdvanceHolders.Clear();
	Object.OtherSections.Clear();
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#Region BelongingsTSEventHandlers

// Procedure - OnStartEdit event handler of the FixedAssets tabular section.
//
&AtClient
Procedure FixedAssetsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
 
		TabularSectionRow = Items.FixedAssets.CurrentData;
		TabularSectionRow.StructuralUnit = MainDepartment;
		
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	
EndProcedure

&AtClient
Procedure FixedAssetsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "FixedAssetsIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "FixedAssets");
	EndIf;
	
EndProcedure

&AtClient
Procedure FixedAssetsOnActivateCell(Item)
	
	CurrentData = Items.FixedAssets.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.FixedAssets.CurrentItem;
		If TableCurrentColumn.Name = "FixedAssetsIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			SelectedRow = Items.FixedAssets.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "FixedAssets");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure FixedAssetsOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure FixedAssetsIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "FixedAssets", StandardProcessing);
	
EndProcedure

#EndRegion

#Region EventHandlersOfThePropertyTabularSectionAttributes

// Procedure - event handler OnChange of
// input field WorksProductsVolumeForDepreciationCalculation in
// string of tabular section FixedAssets.
//
&AtClient
Procedure FixedAssetsVolumeProductsWorksForDepreciationCalculationOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If Not StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		ShowMessageBox(Undefined,NStr("en = '""Product (work) volume for calculating depreciation"" cannot be filled in for the specified depreciation method.'; ru = '""Объем продукции (работ) для исчисления амортизации"" не может быть заполнен для указанного способа начисления амортизации!';pl = 'Dla określonej metody amortyzacji nie można wypełnić pola ""Trwałość użyteczna do metody amortyzacji"".';es_ES = '""Volumen de productos (trabajos) para calcular la depreciación"" no puede rellenarse para el método de depreciación especificado.';es_CO = '""Volumen de productos (trabajos) para calcular la depreciación"" no puede rellenarse para el método de depreciación especificado.';tr = '""Amortisman hesaplamasında kullanılan ürün (iş) hacmi"", belirtilen amortisman tahakkuku yöntemi için doldurulmamıştır.';it = '""Il volume del prodotto (lavoro) per il calcolo degli ammortamenti"" non può essere compilato per il metodo di ammortamento specificato.';de = '""Produkt (Arbeit) Volumen zur Berechnung der Abschreibung"" kann für die angegebene Abschreibungsmethode nicht ausgefüllt werden.'"));
		TabularSectionRow.AmountOfProductsServicesForDepreciationCalculation = 0;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of
// input field UsagePeriodForDepreciationCalculation in string
// of tabular section FixedAssets.
//
&AtClient
Procedure FixedAssetsUsagePeriodForDepreciationCalculationOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		ShowMessageBox(Undefined,NStr("en = 'Cannot fill in ""Useful life for calculating depreciation"" for the specified method of depreciation.'; ru = '""Срок использования для вычисления амортизации"" не может быть заполнен для указанного способа начисления амортизации!';pl = 'Dla określonej metody amortyzacji nie można wypełnić pola ""Liczba amortyzacji do obliczenia"".';es_ES = 'No se puede rellenar la ""Vida útil para calcular la depreciación"" para el método especificado de la depreciación.';es_CO = 'No se puede rellenar la ""Vida útil para calcular la depreciación"" para el método especificado de la depreciación.';tr = 'Belirtilen amortisman yöntemi için ""Amortismanın hesaplanması için yararlı ömür"" doldurulamaz.';it = 'Il ""Vita utile per il calcolo dell''ammortamento"" non può essere compilato per il metodo di calcolo dell''ammortamento specificato!';de = 'Für die angegebene Abschreibungsmethode kann die ""Nutzungsdauer für die Berechnung der Abschreibungen"" nicht angegeben werden.'"));
		TabularSectionRow.UsagePeriodForDepreciationCalculation = 0;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of
// input field FixedAsset in string of tabular section FixedAssets.
//
&AtClient
Procedure FixedAssetsFixedAssetOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	TabularSectionRow.DepreciationChargeItem = DefaultExpenseItem;
	
	If UseDefaultTypeOfAccounting Then
		TabularSectionRow.RegisterDepreciationCharge = IsIncomeAndExpenseGLA(TabularSectionRow.GLExpenseAccount);
	Else
		TabularSectionRow.RegisterDepreciationCharge = True;
	EndIf;
		
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		TabularSectionRow.UsagePeriodForDepreciationCalculation = 0;
	Else
		TabularSectionRow.AmountOfProductsServicesForDepreciationCalculation = 0;
		TabularSectionRow.CurrentOutputQuantity = 0;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler
// of the OutputQuantity edit box in the FixedAssets tabular section string.
//
&AtClient
Procedure FixedAssetsCurrentOutputQuantityOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If Not StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		ShowMessageBox(Undefined,NStr("en = '""Product (work) volume for calculating depreciation"" cannot be filled in for the specified depreciation method.'; ru = '""Объем продукции (работ) для исчисления амортизации"" не может быть заполнен для указанного способа начисления амортизации!';pl = 'Dla określonej metody amortyzacji nie można wypełnić pola ""Trwałość użyteczna do metody amortyzacji"".';es_ES = '""Volumen de productos (trabajos) para calcular la depreciación"" no puede rellenarse para el método de depreciación especificado.';es_CO = '""Volumen de productos (trabajos) para calcular la depreciación"" no puede rellenarse para el método de depreciación especificado.';tr = '""Amortisman hesaplamasında kullanılan ürün (iş) hacmi"", belirtilen amortisman tahakkuku yöntemi için doldurulmamıştır.';it = '""Il volume del prodotto (lavoro) per il calcolo degli ammortamenti"" non può essere compilato per il metodo di ammortamento specificato.';de = '""Produkt (Arbeit) Volumen zur Berechnung der Abschreibung"" kann für die angegebene Abschreibungsmethode nicht ausgefüllt werden.'"));
		TabularSectionRow.CurrentOutputQuantity = 0;
	EndIf;

EndProcedure

&AtClient
Procedure FixedAssetsGLExpenseAccountOnChange(Item)
	
	CurData = Items.FixedAssets.CurrentData;
	If CurData <> Undefined Then
		
		StructureData = New Structure("
		|TabName,
		|Object,
		|GLExpenseAccount,
		|IncomeAndExpenseItems,
		|IncomeAndExpenseItemsFilled,
		|DepreciationChargeItem,
		|RegisterDepreciationCharge,
		|Manual");
		StructureData.Object = Object;
		StructureData.TabName = "FixedAssets";
		FillPropertyValues(StructureData, CurData);
		
		GLAccountsInDocumentsServerCall.CheckItemRegistration(StructureData);
		FillPropertyValues(CurData, StructureData);
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillInventory", False);
		ParametersStructure.Insert("FillAccountsReceivable", False);
		ParametersStructure.Insert("FillAccountsPayable", False);
		ParametersStructure.Insert("FillFixedAssets", True);
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FixedAssetsRegisterDepreciationChargeOnChange(Item)
	
	CurrentData = Items.FixedAssets.CurrentData;
	
	If CurrentData <> Undefined And Not CurrentData.RegisterDepreciationCharge Then
		CurrentData.DepreciationChargeItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillInventory", False);
		ParametersStructure.Insert("FillAccountsReceivable", False);
		ParametersStructure.Insert("FillAccountsPayable", False);
		ParametersStructure.Insert("FillFixedAssets", True);
		FillAddedColumns(ParametersStructure);
	EndIf;
	
EndProcedure

#EndRegion

#Region DirectCostsTSEventHandlers

// Procedure - OnStartEdit event handler of the DirectCosts tabular section.
//
&AtClient
Procedure DirectCostOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
 
		TabularSectionRow = Items.DirectCost.CurrentData;
		TabularSectionRow.StructuralUnit = MainDepartment;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InventoryTSEventHandlers

// Procedure - OnStartEdit event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow
	   AND Not Copy Then
		TabularSectionRow = Items.Inventory.CurrentData;
		If ValueIsFilled(MainWarehouse) Then
			TabularSectionRow.StructuralUnit = MainWarehouse;
		Else
			TabularSectionRow.StructuralUnit = MainDepartment;
		EndIf;
	EndIf;
	
	If NewRow AND Copy Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;
	
	If Item.CurrentItem.Name = "SerialNumbersInventory" Then
		OpenSerialNumbersSelection();
	EndIf;
	
	If Not NewRow Or Copy Then
		Return;	
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection();
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Inventory.CurrentData;
	DriveClientServer.DeleteRowsByConnectionKey(Object.SerialNumbers, CurrentData);
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryGLAccounts" Then
		StandardProcessing = False;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnActivateCell(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Inventory.CurrentItem;
		If TableCurrentColumn.Name = "InventoryGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Inventory.CurrentRow;
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	// Serial numbers
	If UseSerialNumbersBalance<>Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, Items.Inventory.CurrentData);
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlersOfTheInventoryTabularSectionAttributes

&AtClient
Procedure InventoryStructuralUnitOnChange(Item)
	InventoryStructuralUnitOnChangeAtServer();
EndProcedure

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	GetStructureDataForObject(ThisObject, "Inventory", StructureData, TabularSectionRow);
	
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	FillDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
	// Serial numbers
	If UseSerialNumbersBalance <> Undefined Then
		WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,,UseSerialNumbersBalance);
	EndIf;
	// Serial numbers
	
EndProcedure

#EndRegion

#Region TSAttributesEventHandlersCashAssets

&AtClient
Procedure CashAssetsBankOnChange(Item)
	
	FillLineNumbers(CashAssetsBank);
	
EndProcedure

&AtClient
Procedure CashAssetsBankBankAccountPettyCashOnChange(Item)
	
	TabularSectionRow = Items.CashAssetsBank.CurrentData;
	
	StructureData = GetDataCashAssetsBankAccountPettyCashOnChange(TabularSectionRow.BankAccountPettyCash);
	
	TabularSectionRow.CashCurrency = StructureData.Currency;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
		Object.Company,
		TabularSectionRow.AmountCur,
		TabularSectionRow.CashCurrency,
		Object.Date);
	
EndProcedure

&AtClient
Procedure CashAssetsBankAmountCurOnChange(Item)
	
	TabularSectionRow = Items.CashAssetsBank.CurrentData;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
		Object.Company,
		TabularSectionRow.AmountCur,
		TabularSectionRow.CashCurrency,
		Object.Date);
	
EndProcedure

&AtClient
Procedure CashAssetsCashOnChange(Item)
	
	FillLineNumbers(CashAssetsCash);
	
EndProcedure

&AtClient
Procedure CashAssetsCashBankAccountPettyCashOnChange(Item)
	
	TabularSectionRow = Items.CashAssetsCash.CurrentData;
	
	StructureData = GetDataCashAssetsBankAccountPettyCashOnChange(TabularSectionRow.BankAccountPettyCash);
	
	TabularSectionRow.CashCurrency = StructureData.Currency;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
		Object.Company,
		TabularSectionRow.AmountCur,
		TabularSectionRow.CashCurrency,
		Object.Date);
	
EndProcedure

&AtClient
Procedure CashAssetsCashAmountCurOnChange(Item)
	
	TabularSectionRow = Items.CashAssetsCash.CurrentData;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
		Object.Company,
		TabularSectionRow.AmountCur,
		TabularSectionRow.CashCurrency,
		Object.Date);
	
EndProcedure

#EndRegion

#Region TSAttributesEventHandlersAccountsReceivable

// Procedure - OnChange event handler of the
// Counterparty edit box in the AccountsReceivable tabular section string.
// Generates the Contract
// column value, recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsReceivableCounterpartyOnChange(Item)

	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	GetStructureDataForObject(ThisObject, "AccountsReceivable", StructureData, TabularSectionRow);
	
	FillDataCounterpartyOnChange(StructureData);
	FillPropertyValues(TabularSectionRow, StructureData);
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
		Object.Company,
		TabularSectionRow.AmountCur,
		StructureData.SettlementsCurrency,
		Object.Date);
		
	AdjustDocumentType(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange event handler of the
// Contract edit box in the AccountsReceivable tabular section string.
// Generates the Contract
// column value, recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsReceivableContractOnChange(Item)
	
	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	GetStructureDataForObject(ThisObject, "AccountsReceivable", StructureData, TabularSectionRow);
	
	FillDataContractOnChange(StructureData);
	FillPropertyValues(TabularSectionRow, StructureData);
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
		Object.Company,
		TabularSectionRow.AmountCur,
		StructureData.SettlementsCurrency,
		Object.Date);
		
	AdjustDocumentType(TabularSectionRow);
	
EndProcedure

// Procedure - SelectionStart event handler of
// the Contract edit box in the AccountsReceivable tabular section string.
//
&AtClient
Procedure AccountsReceivableAccountsContractBeginChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	
	FormParameters = GetChoiceFormParameters(
		Object.Ref, 
		Object.Company, 
		TabularSectionRow.Counterparty, 
		TabularSectionRow.Contract, 
		Undefined, 
		"AccountsReceivable"
	);
	
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the
// AmountsCurr edit box in the AccountsReceivable tabular section string.
// recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsReceivableAmountCurOnChange(Item)
	
	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	
	StructureData = New Structure("Contract", TabularSectionRow.Contract);
	FillDataContractOnChange(StructureData);

	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(Object.Company, TabularSectionRow.AmountCur,
																								 StructureData.SettlementsCurrency,
																								 Object.Date);
EndProcedure

// Procedure - AfterDeletion event handler of the AccountsReceivable tabular section.
//
&AtClient
Procedure AccountsReceivableAfterDeleteRow(Item)

	SetAccountsAttributesVisible(, , "AccountsReceivable");

EndProcedure

&AtClient
Procedure AccountsReceivableSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableSelection(ThisObject, "AccountsReceivable", SelectedRow, Field, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure AccountsReceivableOnActivateCell(Item)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnActivateCell(ThisObject, "AccountsReceivable", ThisIsNewRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure AccountsReceivableOnStartEdit(Item, NewRow, Clone)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	EndIf;
	
EndProcedure

&AtClient
Procedure AccountsReceivableOnEditEnd(Item, NewRow, CancelEdit)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnEditEnd(ThisIsNewRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure AccountsReceivableGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.GLAccountsStartChoice(ThisObject, "AccountsReceivable", StandardProcessing);  
	EndIf;
	
EndProcedure

#EndRegion

#Region TSAttributesEventhandlersAccountsPayable

// Procedure - OnChange event handler of
// the Counterparty edit box in the AccountsPayable tabular section string.
// Generates the Contract
// column value, recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsPayableCounterpartyOnChange(Item)

	TabularSectionRow = Items.AccountsPayable.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	GetStructureDataForObject(ThisObject, "AccountsPayable", StructureData, TabularSectionRow);
	
	FillDataCounterpartyOnChange(StructureData);
	FillPropertyValues(TabularSectionRow, StructureData);
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
		Object.Company,
		TabularSectionRow.AmountCur,
		StructureData.SettlementsCurrency,
		Object.Date);
	
	AdjustDocumentType(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange event handler of
// the Contract edit box in the AccountsPayable tabular section string.
// Generates the Contract
// column value, recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsPayableContractOnChange(Item)
	
	TabularSectionRow = Items.AccountsPayable.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	GetStructureDataForObject(ThisObject, "AccountsPayable", StructureData, TabularSectionRow);
	
	FillDataContractOnChange(StructureData);
	FillPropertyValues(TabularSectionRow, StructureData);
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
		Object.Company,
		TabularSectionRow.AmountCur,
		StructureData.SettlementsCurrency,
		Object.Date);
	
	AdjustDocumentType(TabularSectionRow);
	
EndProcedure

// Procedure - SelectionStart event handler of
// the Contract edit box in the AccountsPayable tabular section string.
//
&AtClient
Procedure AccountsPayableContractBeginChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.AccountsPayable.CurrentData;
	
	FormParameters = GetChoiceFormParameters(Object.Ref,
		Object.Company,
		TabularSectionRow.Counterparty,
		TabularSectionRow.Contract, 
		Undefined,
		"AccountsPayable"
	);
	
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of
// the AmountCurr edit box in the AccountsPayable tabular section string.
// recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsPayableAmountCurOnChange(Item)
	
	TabularSectionRow = Items.AccountsPayable.CurrentData;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
		Object.Company,
		TabularSectionRow.AmountCur,
		TabularSectionRow.Contract,
		Object.Date);
	
EndProcedure

// Procedure - AfterDeletion event handler of the AccountsPayable tabular section.
//
&AtClient
Procedure AccountsPayableAfterDeleteRow(Item)

	SetAccountsAttributesVisible(, , "AccountsPayable");

EndProcedure

&AtClient
Procedure AccountsPayableSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableSelection(ThisObject, "AccountsPayable", SelectedRow, Field, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure AccountsPayableOnActivateCell(Item)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnActivateCell(ThisObject, "AccountsPayable", ThisIsNewRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure AccountsPayableOnStartEdit(Item, NewRow, Clone)
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	EndIf;
	
EndProcedure

&AtClient
Procedure AccountsPayableOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure AccountsPayableGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	GLAccountsInDocumentsClient.GLAccountsStartChoice(ThisObject, "AccountsPayable", StandardProcessing);  
	
EndProcedure

#EndRegion

#Region TSAttributesEventPayrollPayments

// Procedure - OnStartEdit event handler of the Payroll tabular section.
//
&AtClient
Procedure PayrollOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		TabularSectionRow = Items.Payroll.CurrentData;
		TabularSectionRow.Currency = CurrencyByDefault;
		
		TabularSectionRow.StructuralUnit = MainDepartment;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the
// Currency edit box in the Payroll tabular section string.
// recalculates amount in the man. currency. account from amount in the contract currency.
//
&AtClient
Procedure PayrollCurrencyOnChange(Item)
	
	TabularSectionRow = Items.Payroll.CurrentData;
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(Object.Company, TabularSectionRow.AmountCur,
																								 TabularSectionRow.Currency,
																								 Object.Date);
EndProcedure

// Procedure - OnChange event handler of the
// AmountCurr edit box in the Payroll tabular section string.
// recalculates amount in the man. currency. account from amount in the contract currency.
//
&AtClient
Procedure PayrollAmountCurOnChange(Item)
	
	TabularSectionRow = Items.Payroll.CurrentData;

	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(Object.Company, TabularSectionRow.AmountCur,
																								 TabularSectionRow.Currency,
																								 Object.Date);
EndProcedure

// Procedure - OnChange event handler of
// the RegistrationPeriod edit box in the Payroll tabular section string.
// Aligns registration period on the month start.
//
&AtClient
Procedure RegisterRecordsPayrollPeriodOnChange(Item)
	
	CurRow = Items.Payroll.CurrentData;
	CurRow.RegistrationPeriod = BegOfMonth(CurRow.RegistrationPeriod);
	
EndProcedure

#EndRegion

#Region TSAttributesEventHandlersAdvanceHolderPayments

// Procedure - OnStartEdit event handler of the AdvanceHolders tabular section.
//
&AtClient
Procedure AdvanceHoldersOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		TabularSectionRow = Items.AdvanceHolders.CurrentData;
		TabularSectionRow.Currency = CurrencyByDefault;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the
// Currency edit box in the AdvanceHolders tabular section string.
// recalculates amount in the man. currency. account from amount in the contract currency.
//
&AtClient
Procedure AdvanceHoldersCurrencyOnChange(Item)
	
	TabularSectionRow = Items.AdvanceHolders.CurrentData;
	
	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(Object.Company, TabularSectionRow.AmountCur,
																			 TabularSectionRow.Currency,
																			 Object.Date);
EndProcedure

// Procedure - OnChange event handler of the
// AmountCurr edit box in the AdvanceHolders tabular section string.
// recalculates amount in the man. currency. account from amount in the contract currency.
//
&AtClient
Procedure AdvanceHoldersAmountCurOnChange(Item)
	
	TabularSectionRow = Items.AdvanceHolders.CurrentData;

	TabularSectionRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(Object.Company, TabularSectionRow.AmountCur,
																								 TabularSectionRow.Currency,
																								 Object.Date);
EndProcedure

&AtClient
Procedure AdvanceHoldersEmployeeSettlementsOnChange(Item)
	
	CurRow = Items.AdvanceHolders.CurrentData;
	AdjustDocumentType(CurRow);
	
EndProcedure

&AtClient
Procedure AdvanceHoldersDocumentTypeOnChange(Item)
	
	CurRow = Items.AdvanceHolders.CurrentData;
	AdjustDocumentType(CurRow);
	
EndProcedure

&AtClient
Procedure SettlementsWithAdvanceHoldersDocumentOnChange(Item)
	
	CurRow = Items.AdvanceHolders.CurrentData;
	DocumentData = GetDocumentData(CurRow.Document);
	FillPropertyValues(CurRow, DocumentData);
	
EndProcedure

#EndRegion

#Region TSAttributesEventHandlersOtherSections

// Procedure - OnChange event handler of the Account input field.
// Transactions tabular section.
//
&AtClient
Procedure OtherSectionsAccountOnChange(Item)
	
	CurrentRow = Items.OtherSections.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.Account);
	
	If Not StructureData.Currency Then
		CurrentRow.Currency = Undefined;
		CurrentRow.AmountCur = Undefined;
	EndIf;
	
EndProcedure

// Procedure - SelectionStart event handler of the Currency input field.
// Transactions tabular section.
//
&AtClient
Procedure OtherSectionsCurrencyStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.OtherSections.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.Account);
	
	If Not StructureData.Currency Then
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.Account) Then
			ShowMessageBox(Undefined,NStr("en = 'Currency flag is not set for the selected account.'; ru = 'У выбранного счета не установлен признак валютный!';pl = 'Dla tego rachunku nie zaznaczono waluty.';es_ES = 'Casilla de monedas no está marcada para el importe seleccionado.';es_CO = 'Casilla de monedas no está marcada para el importe seleccionado.';tr = 'Seçilen hesap için para birimi bayrağı ayarlanmamış.';it = 'Il contrassegno valuta non è impostato per il conto selezionato.';de = 'Das Währungskennzeichen ist für das ausgewählte Konto nicht festgelegt.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the account first.'; ru = 'Укажите в начале счет!';pl = 'Najpierw określ rachunek.';es_ES = 'Especificar primero la cuenta.';es_CO = 'Especificar primero la cuenta.';tr = 'Önce hesabı belirtin.';it = 'Specificare il conto prima di tutto.';de = 'Geben Sie zuerst das Konto an.'"));
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Currency input field.
// Transactions tabular section.
//
&AtClient
Procedure OtherSectionsCurrencyOnChange(Item)
	
	CurrentRow = Items.OtherSections.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.Account);
	
	If Not StructureData.Currency Then
		CurrentRow.Currency = Undefined;
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.Account) Then
			ShowMessageBox(Undefined,NStr("en = 'Currency flag is not set for the selected account.'; ru = 'У выбранного счета не установлен признак валютный!';pl = 'Dla tego rachunku nie zaznaczono waluty.';es_ES = 'Casilla de monedas no está marcada para el importe seleccionado.';es_CO = 'Casilla de monedas no está marcada para el importe seleccionado.';tr = 'Seçilen hesap için para birimi bayrağı ayarlanmamış.';it = 'Il contrassegno valuta non è impostato per il conto selezionato.';de = 'Das Währungskennzeichen ist für das ausgewählte Konto nicht festgelegt.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the account first.'; ru = 'Укажите в начале счет!';pl = 'Najpierw określ rachunek.';es_ES = 'Especificar primero la cuenta.';es_CO = 'Especificar primero la cuenta.';tr = 'Önce hesabı belirtin.';it = 'Specificare il conto prima di tutto.';de = 'Geben Sie zuerst das Konto an.'"));
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - SelectionStart event handler of the AmountCurr input field.
// Transactions tabular section.
//
&AtClient
Procedure OtherSectionsAmountCurStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.OtherSections.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.Account);
	
	If Not StructureData.Currency Then
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.Account) Then
			ShowMessageBox(Undefined,NStr("en = 'Currency flag is not set for the selected account.'; ru = 'У выбранного счета не установлен признак валютный!';pl = 'Dla tego rachunku nie zaznaczono waluty.';es_ES = 'Casilla de monedas no está marcada para el importe seleccionado.';es_CO = 'Casilla de monedas no está marcada para el importe seleccionado.';tr = 'Seçilen hesap için para birimi bayrağı ayarlanmamış.';it = 'Il contrassegno valuta non è impostato per il conto selezionato.';de = 'Das Währungskennzeichen ist für das ausgewählte Konto nicht festgelegt.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the account first.'; ru = 'Укажите в начале счет!';pl = 'Najpierw określ rachunek.';es_ES = 'Especificar primero la cuenta.';es_CO = 'Especificar primero la cuenta.';tr = 'Önce hesabı belirtin.';it = 'Specificare il conto prima di tutto.';de = 'Geben Sie zuerst das Konto an.'"));
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the AmountCurr input field.
// Transactions tabular section.
//
&AtClient
Procedure OtherSectionsAmountCurOnChange(Item)
	
	CurrentRow = Items.OtherSections.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.Account);
	
	If Not StructureData.Currency Then
		CurrentRow.AmountCur = Undefined;
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.Account) Then
			ShowMessageBox(Undefined,NStr("en = 'Currency flag is not set for the selected account.'; ru = 'У выбранного счета не установлен признак валютный!';pl = 'Dla tego rachunku nie zaznaczono waluty.';es_ES = 'Casilla de monedas no está marcada para el importe seleccionado.';es_CO = 'Casilla de monedas no está marcada para el importe seleccionado.';tr = 'Seçilen hesap için para birimi bayrağı ayarlanmamış.';it = 'Il contrassegno valuta non è impostato per il conto selezionato.';de = 'Das Währungskennzeichen ist für das ausgewählte Konto nicht festgelegt.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the account first.'; ru = 'Укажите в начале счет!';pl = 'Najpierw określ rachunek.';es_ES = 'Especificar primero la cuenta.';es_CO = 'Especificar primero la cuenta.';tr = 'Önce hesabı belirtin.';it = 'Specificare il conto prima di tutto.';de = 'Geben Sie zuerst das Konto an.'"));
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - event handler AfterWriteAtServer form.
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillInventory", True);
	ParametersStructure.Insert("FillAccountsReceivable", True);
	ParametersStructure.Insert("FillAccountsPayable", True);
	ParametersStructure.Insert("FillFixedAssets", True);
	
	FillAddedColumns(ParametersStructure);
	
	// Filling in the additional attributes of tabular section.
	SetAccountsAttributesVisible(, , "AccountsPayable");
	SetAccountsAttributesVisible(, , "AccountsReceivable");
	
	ReadDocumentTypes();
	
EndProcedure

&AtClient
Procedure AccountsPayableDocumentTypeOnChange(Item)
	
	TabularSectionRow = Items.AccountsPayable.CurrentData;
	AdjustDocumentType(TabularSectionRow);
	ChangeAdvanceFlag(TabularSectionRow, False);
	
EndProcedure

&AtClient
Procedure AccountsPayableDocumentTypeChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	TabularSectionRow = Items.AccountsPayable.CurrentData;
	PreviousDocumentTypeValue = TabularSectionRow.DocumentType;
	
EndProcedure

&AtClient
Procedure InventoryDocumentTypeOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	AdjustDocumentType(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange event handler of the Document box of the AccountsPayable table.
//
&AtClient
Procedure AccountsPayableDocumentOnChange(Item)
	
	TabularSectionRow = Items.AccountsPayable.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashVoucher")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ExpenseReport") Then
		TabularSectionRow.AdvanceFlag = True;
	ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ArApAdjustments") Then
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
	DocumentData = GetDocumentData(TabularSectionRow.Document);
	FillPropertyValues(TabularSectionRow, DocumentData);
	
EndProcedure

&AtClient
Procedure InventoryDocumentOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;	
	DocumentData = GetDocumentData(TabularSectionRow.Document);
	FillPropertyValues(TabularSectionRow, DocumentData);
	
EndProcedure

&AtClient
Procedure AccountsReceivableDocumentTypeOnChange(Item)
	
	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	AdjustDocumentType(TabularSectionRow);
	ChangeAdvanceFlag(TabularSectionRow);
	
EndProcedure

&AtClient
Procedure AccountsReceivableDocumentTypeChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	PreviousDocumentTypeValue = TabularSectionRow.DocumentType;
	
EndProcedure

// Procedure - OnChange event handler of the Document box of the AccountsReceivable table.
//
&AtClient
Procedure AccountsReceivableDocumentOnChange(Item)
	
	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
		Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt")
		Or TypeOf(TabularSectionRow.Document) = Type("DocumentRef.OnlineReceipt") Then
		TabularSectionRow.AdvanceFlag = True;
	ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ArApAdjustments") Then
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
	DocumentData = GetDocumentData(TabularSectionRow.Document);
	FillPropertyValues(TabularSectionRow, DocumentData);
	
EndProcedure

// Procedure - OnChange event handler of the Autogenerate box.
//
&AtClient
Procedure AutogenerationOnChange(Item)
	
	SetAutogenerationFieldsVisible();
	
EndProcedure

// Procedure - OnChange event handler of the AutogenerateInventoryAcqusitionDocuments box.
//
&AtClient
Procedure AutogenerateInventoryAcqusitionDocumentsOnChange(Item)
	
	AutogenerateInventoryAcqusitionDocumentsOnChangeAtServer();
	SetAutogenerationFieldsVisible();
	
EndProcedure

&AtServer
Procedure AutogenerateInventoryAcqusitionDocumentsOnChangeAtServer()
	
	UpdateInventoryDocumentTypeChoiceList();
	
	OpeningBalanceEntryName = Metadata.Documents.OpeningBalanceEntry.Name;
	
	If Object.AutogenerateInventoryAcqusitionDocuments Then
		
		For Each InventoryRow In Object.Inventory Do
			
			If InventoryRow.DocumentType = OpeningBalanceEntryName Then
			
				InventoryRow.Document = Undefined;
				InventoryRow.DocumentType = "";
				
			EndIf;
			
		EndDo;
			
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.DataImportFromExternalSources
&AtClient
Procedure ImportDataFromExternalSourceInventory(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.Inventory";
	
	DocumentAttributes = New Structure;
	DocumentAttributes.Insert("InventoryValuationMethod", Object.InventoryValuationMethod);
	DataLoadSettings.Insert("DocumentAttributes", DocumentAttributes);
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceAccountsReceivable(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable";
	
	DocumentAttributes = New Structure;
	DocumentAttributes.Insert("Company", Object.Company);
	DocumentAttributes.Insert("Date", Object.Date);
	DataLoadSettings.Insert("DocumentAttributes", DocumentAttributes);
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceAccountsPayable(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsPayable";
	
	DocumentAttributes = New Structure;
	DocumentAttributes.Insert("Company", Object.Company);
	DocumentAttributes.Insert("Date", Object.Date);
	DataLoadSettings.Insert("DocumentAttributes", DocumentAttributes);
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure DataImportFromExternalSourcesBankAccounts(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.CashAssets";
	DataLoadSettings.Insert("AccountType", "BankAccount");
	DataLoadSettings.Insert("CreateIfNotMatched", True);
	DocumentAttributes = New Structure;
	DocumentAttributes.Insert("Company", Object.Company);
	DocumentAttributes.Insert("Date", Object.Date);
	DataLoadSettings.Insert("DocumentAttributes", DocumentAttributes);
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure DataImportFromExternalSourcesCashAccounts(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.CashAssets";
	DataLoadSettings.Insert("AccountType", "CashAccount");
	DataLoadSettings.Insert("CreateIfNotMatched", True);
	DocumentAttributes = New Structure;
	DocumentAttributes.Insert("Company", Object.Company);
	DocumentAttributes.Insert("Date", Object.Date);
	DataLoadSettings.Insert("DocumentAttributes", DocumentAttributes);
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult, AdditionalParameters);
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult, AdditionalParameters)
	
	FillingObjectFullName = AdditionalParameters.FillingObjectFullName;
	If FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.CashAssets" Then
		Object.CashAssets.Clear();
		For Each CurRow In CashAssetsBank Do
			FillPropertyValues(Object.CashAssets.Add(), CurRow);
		EndDo;
		For Each CurRow In CashAssetsCash Do
			FillPropertyValues(Object.CashAssets.Add(), CurRow);
		EndDo;
	EndIf;
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object, ThisObject);
	
	If FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.CashAssets" Then
		FillCashAssetsTables();
	EndIf;
	
EndProcedure

// End StandardSubsystems.DataImportFromExternalSource

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

#EndRegion

#EndRegion

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False);
	
EndFunction

&AtServer
Procedure FillCheckDocumentType(TabularSections, MessageText, Cancel)

	MetaTS = Metadata.Documents.OpeningBalanceEntry.TabularSections;
		
	For Each TSName In TabularSections Do
		
		ListName = MetaTS[TSName].Presentation();
		
		For Each CurRow In Object[TSName] Do
			If Not ValueIsFilled(CurRow.DocumentType) Then
				MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, CurRow.LineNumber, ListName);
				MessageField = CommonClientServer.PathToTabularSection("Object." + TSName, CurRow.LineNumber, "DocumentType");				
				CommonClientServer.MessageToUser(MessageToUserText, , MessageField, , Cancel);
			EndIf;
		EndDo;
		
	EndDo;	

EndProcedure

&AtClient 
Procedure FillDocumentEmptyRef(TableNames)
	
	For Each TableName In TableNames Do
		For Each CurRow In Object[TableName] Do
			If Not ValueIsFilled(CurRow.Document) And ValueIsFilled(CurRow.DocumentType) Then
				CurRow.Document = PredefinedValue("Document." + CurRow.DocumentType + ".EmptyRef");
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Procedure UpdateInventoryDocumentTypeChoiceList()
	
	ChoiceList = Items.InventoryDocumentType.ChoiceList;
	OpeningBalanceEntryMetadata = Metadata.Documents.OpeningBalanceEntry;
	OpeningBalanceEntryMetadataName = OpeningBalanceEntryMetadata.Name;
	OpeningBalanceEntryMetadataPresentation = OpeningBalanceEntryMetadata.Synonym;
	ChoiceListEntry = ChoiceList.FindByValue(OpeningBalanceEntryMetadataName);
	
	If Object.AutogenerateInventoryAcqusitionDocuments Then
		If ChoiceListEntry <> Undefined Then
			ChoiceList.Delete(ChoiceListEntry);
		EndIf;		
	Else
		If ChoiceListEntry = Undefined Then
			ChoiceList.Add(OpeningBalanceEntryMetadataName, OpeningBalanceEntryMetadataPresentation);	
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_DateChangeProcessing()
	
	If ValueIsFilled(Object.Company) Then
		UpdateInventoryValuationMethod();
		SetItemsVisibleEnabled();
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateInventoryValuationMethod()
	
	CompanyData = GetCompanyDataOnChange(Object.Company);
	Object.InventoryValuationMethod = CompanyData.InventoryValuationMethod;
	
EndProcedure

#Region GLAccounts

&AtClientAtServerNoContext
Procedure GetStructureDataForObject(Form, TabName, StructureData, TabRow)
	
	StructureData.Insert("TabName", 			TabName);
	StructureData.Insert("Object",				Form.Object);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		StructureData.Insert("GLAccounts",			TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled",	TabRow.GLAccountsFilled);
	EndIf;
	
	If TabName = "Inventory" Then
		
		StructureData.Insert("Products", 			TabRow.Products);
		StructureData.Insert("StructuralUnit",		TabRow.StructuralUnit);
		StructureData.Insert("StructuralUnitInTabularSection", True);
		
		If StructureData.UseDefaultTypeOfAccounting Then
			StructureData.Insert("ProductGLAccounts",	True);
			StructureData.Insert("InventoryGLAccount",	TabRow.InventoryGLAccount);
		EndIf;
		
	Else
		
		StructureData.Insert("Counterparty",	TabRow.Counterparty);
		StructureData.Insert("Contract",		TabRow.Contract);
		
		If StructureData.UseDefaultTypeOfAccounting Then
			
			StructureData.Insert("CounterpartyGLAccounts",	True);
			
			If TabName = "AccountsPayable" Then
				StructureData.Insert("AccountsPayableGLAccount",	TabRow.AccountsPayableGLAccount);
				StructureData.Insert("AdvancesPaidGLAccount",		TabRow.AdvancesPaidGLAccount);
			ElsIf TabName = "AccountsReceivable" Then
				StructureData.Insert("AccountsReceivableGLAccount",	TabRow.AccountsReceivableGLAccount);
				StructureData.Insert("AdvancesReceivedGLAccount",	TabRow.AdvancesReceivedGLAccount);
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(ParametersStructure)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	StructureArray = New Array();
	
	If UseDefaultTypeOfAccounting Then
		
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
		
		If ParametersStructure.FillInventory Then
			
			StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters);
			GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters);
			
			StructureArray.Add(StructureData);
			
		EndIf;
		
		If ParametersStructure.FillAccountsReceivable Then
			
			StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "AccountsReceivable");
			GLAccountsInDocuments.CompleteCounterpartyStructureData(StructureData, ObjectParameters, "AccountsReceivable");
			
			StructureArray.Add(StructureData);
			
		EndIf;
		
		If ParametersStructure.FillAccountsPayable Then
			
			StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "AccountsPayable");
			GLAccountsInDocuments.CompleteCounterpartyStructureData(StructureData, ObjectParameters, "AccountsPayable");
			
			StructureArray.Add(StructureData);
			
		EndIf;
		
	EndIf;
	
	If ParametersStructure.FillFixedAssets Then
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "FixedAssets");
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "FixedAssets");
		
		StructureArray.Add(StructureData);
		
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
EndProcedure

&AtServerNoContext
Function IsIncomeAndExpenseGLA(Account)
	Return GLAccountsInDocumentsServerCall.IsIncomeAndExpenseGLA(Account);
EndFunction

#EndRegion

&AtServer
Procedure DateOnChangeAtServer()
	ProcessingCompanyVATNumbers();
EndProcedure

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	
	If Object.AccountingSection = Enums.OpeningBalanceAccountingSections.Taxes Then
		WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);
	Else
		Items.CompanyVATNumber.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion