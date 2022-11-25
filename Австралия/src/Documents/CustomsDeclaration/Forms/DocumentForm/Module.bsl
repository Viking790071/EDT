
#Region Variables

&AtClient
Var CurrentCommodityGroup;

&AtClient
Var CurrentProduct;

&AtClient
Var CurrentInvoice;

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.CustomsDeclaration.TabularSections.Inventory, DataLoadSettings, ThisObject);
	
	PrintManagement.OnCreateAtServer(ThisObject);
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	If Parameters.Key.IsEmpty() Then
		OnCreateOnReadCommonActions();
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		Object.ExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("OtherExpenses");
	EndIf;
	
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance);
	
	PickProductsInDocuments.AssignPickForm(SelectionOpenParameters, Object.Ref.Metadata().Name, "Inventory");
	
	Items.InventoryDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillHeader", True);
		ParametersStructure.Insert("FillInventory", False);
		
		FillAddedColumns(ParametersStructure);
	
	EndIf;
	
	Items.GLAccounts.Visible = UseDefaultTypeOfAccounting;
	Items.InventoryGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	ProcessingCompanyVATNumbers();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Object.CommodityGroups.Count() = 0 Then
	
		ShowAllItem = Items.ShowAll;
		ShowAllItem.Check = Not ShowAllItem.Check;
		ActivateCommodityGroup();
		
	EndIf;
	
	SetCounterpartyProperties();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.SupplierInvoice.Form.ChoiceForm" Then
		
		ProcessInvoicesSelection(SelectedValue);
		RefreshFormFooter();
		
	ElsIf GLAccountsInDocumentsClient.IsGLAccountsChoiceProcessing(ChoiceSource.FormName) Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	EndIf;
	
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
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	IsSupplier = Common.ObjectAttributeValue(Object.Counterparty, "Supplier");
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillHeader", True);
		ParametersStructure.Insert("FillInventory", True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	OnCreateOnReadCommonActions();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillHeader", False);
		ParametersStructure.Insert("FillInventory", True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;

EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandler

&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		StructureData = GetDataCounterpartyOnChange();
		
		Object.Contract = StructureData.Contract;
		ContractBeforeChange = Contract;
		Contract = Object.Contract;
		
		ProcessContractChangeFragment(ContractBeforeChange, StructureData);
		
	Else
		
		Object.Contract = Contract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetContractChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract,
		Object.OperationKind);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OtherDutyToExpensesOnChange(Item)
	
	SetGroupExpensesItemsVisible();
	
EndProcedure

&AtClient
Procedure SupplierOnChange(Item)
	
	If Supplier <> Object.Supplier Then
		
		If Object.CommodityGroups.Count() Or Object.Inventory.Count() Then
			
			ShowQueryBox(
				New NotifyDescription("SupplierChangeQueryBoxProcessing", ThisObject),
				InventoryWillBeClearedMessageText(),
				QuestionDialogMode.YesNo);
			
		Else
			
			SupplierChangeProcessing();
			
		EndIf;
		
	Else
		
		Object.SupplierContract = SupplierContract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SupplierContractOnChange(Item)
	
	If Not SupplierContract = Object.SupplierContract Then
		
		If Object.CommodityGroups.Count() Or Object.Inventory.Count() Then
			
			ShowQueryBox(
				New NotifyDescription("SupplierContractChangeQueryBoxProcessing", ThisObject),
				InventoryWillBeClearedMessageText(),
				QuestionDialogMode.YesNo);
			
		Else
		
			ProcessSupplierContractChange();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SupplierContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	FormParameters = GetSupplierContractChoiceFormParameters(
		PredefinedValue("Document.SupplierInvoice.EmptyRef"),
		Object.Company,
		Object.Supplier,
		Object.SupplierContract);
		
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "Attachable_DateChangeProcessing", "Date");
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	If Company <> Object.Company Then
		
		If Object.CommodityGroups.Count() Or Object.Inventory.Count() Then
			
			ShowQueryBox(
				New NotifyDescription("CompanyChangeQueryBoxProcessing", ThisObject),
				InventoryWillBeClearedMessageText(),
				QuestionDialogMode.YesNo);
			
		Else
			
			CompanyChangeProcessing();
			
		EndIf;
		
	Else
		
		Object.Contract = Contract;
		Object.SupplierContract = SupplierContract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies();
	Modified = True;
	
EndProcedure

&AtClient
Procedure VATIsDueOnChange(Item)
	VATIsDueOnChangeAtServer();
EndProcedure

&AtClient
Procedure GLAccountsClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	GLAccountsInDocumentsClient.OpenCounterpartyGLAccountsForm(ThisObject, Object, "");
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtServer
Procedure SetProjectVisible()
	
	ExpenseItemType = Common.ObjectAttributeValue(Object.ExpenseItem, "IncomeAndExpenseType");
	Items.Project.Visible = Object.OtherDutyToExpenses
		And (ExpenseItemType = Catalogs.IncomeAndExpenseTypes.OtherExpenses);
	
EndProcedure

&AtClient
Procedure OtherDutyGLAccountOnChange(Item)
	
	SetProjectVisible();
	
	Structure = New Structure("Object,OtherDutyGLAccount,ExpenseItem");
	Structure.Object = Object;
	FillPropertyValues(Structure, Object);
	
	GLAccountsInDocumentsServerCall.CheckItemRegistration(Structure);
	FillPropertyValues(Object, Structure);
	
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	SetCounterpartyProperties();
EndProcedure

&AtClient
Procedure OperationKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ChoiceData = New ValueList;
	ChoiceData.Add(PredefinedValue("Enum.OperationTypesCustomsDeclaration.Customs"));	
	ChoiceData.Add(PredefinedValue("Enum.OperationTypesCustomsDeclaration.Broker"));	
	
EndProcedure

&AtClient
Procedure ExpenseItemOnChange(Item)
	SetProjectVisible();
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfCommodityGroupsTable

&AtClient
Procedure CommodityGroupsOnActivateRow(Item)
	
	CommodityGroupsRow = Item.CurrentData;
	
	If CommodityGroupsRow = Undefined Then
		
		CurrentCommodityGroup = Undefined;
		
	Else
		
		CurrentCommodityGroup = CommodityGroupsRow.CommodityGroup;
		
	EndIf;
	
	AttachIdleHandler("ActivateCommodityGroup", 0.2, True);
	
EndProcedure

&AtClient
Procedure CommodityGroupsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		
		NewCommodityGroup = NewCommodityGroup();
		Item.CurrentData.CommodityGroup = NewCommodityGroup;
		CurrentCommodityGroup = NewCommodityGroup;
		ModifyInventoryCommodityGroupChoiceList(Undefined, NewCommodityGroup);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommodityGroupsBeforeEditEnd(Item, NewRow, CancelEdit, Cancel)
	
	If NewRow And CancelEdit Then
		
		ModifyInventoryCommodityGroupChoiceList(CurrentCommodityGroup, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommodityGroupsBeforeDeleteRow(Item, Cancel)
	
	CGSelectedRows = Items.CommodityGroups.SelectedRows;
	
	For Each CommodityGroupsRowID In CGSelectedRows Do
		
		CommodityGroupsRow = Object.CommodityGroups.FindByID(CommodityGroupsRowID);
		
		ModifyInventoryCommodityGroupChoiceList(CommodityGroupsRow.CommodityGroup, Undefined);
		
		InventoryRows = Object.Inventory.FindRows(New Structure("CommodityGroup", CommodityGroupsRow.CommodityGroup));
		
		For Each InventoryRow In InventoryRows Do
			
			InventoryRow.CommodityGroup = 0;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure CommodityGroupsCommodityGroupOnChange(Item)
	
	CommodityGroupsRow = Items.CommodityGroups.CurrentData;
	
	NewCommodityGroup = CommodityGroupsRow.CommodityGroup;
	
	If Object.CommodityGroups.FindRows(New Structure("CommodityGroup", NewCommodityGroup)).Count() > 1 Then
		
		CommodityGroupsRow.CommodityGroup = CurrentCommodityGroup;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Commodity group ""%1"" already exists. Please specify different value.'; ru = 'Группа номенклатуры ""%1"" уже существует. Выберите другой элемент.';pl = 'Grupa towarów""%1"" już istnieje. Proszę podać inną wartość.';es_ES = 'Grupo de comodidad ""%1"" ya existe. Por favor, especifique un valor diferente.';es_CO = 'Grupo de comodidad ""%1"" ya existe. Por favor, especifique un valor diferente.';tr = 'Emtia grubu ""%1"" zaten mevcut Lütfen farklı bir değer belirtin.';it = 'Il gruppo merceologico ""%1"" già esiste. Si prega di specificare un valore differente.';de = 'Die Warengruppe ""%1"" existiert bereits. Bitte geben Sie einen anderen Wert an.'"),
			NewCommodityGroup);
			
		CommodityGroupField = CommonClientServer.PathToTabularSection("Object.CommodityGroups", CommodityGroupsRow.LineNumber, "CommodityGroup");
		
		CommonClientServer.MessageToUser(MessageText, , CommodityGroupField);
		
	ElsIf CommodityGroupsRow.CommodityGroup <> CurrentCommodityGroup Then
		
		InventoryRows = Object.Inventory.FindRows(New Structure("CommodityGroup", CurrentCommodityGroup));
		
		For Each InventoryRow In InventoryRows Do
			
			InventoryRow.CommodityGroup = NewCommodityGroup;
			
		EndDo;
		
		ModifyInventoryCommodityGroupChoiceList(CurrentCommodityGroup, NewCommodityGroup);
		
		CurrentCommodityGroup = NewCommodityGroup;
		
		ActivateCommodityGroup();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommodityGroupsOriginOnChange(Item)
	
	CommodityGroupsRow = Items.CommodityGroups.CurrentData;
	
	InventoryRows = Object.Inventory.FindRows(New Structure("CommodityGroup", CurrentCommodityGroup));
	
	For Each InventoryRow In InventoryRows Do
		
		InventoryRow.Origin = CommodityGroupsRow.Origin;
		
	EndDo;
	
	
EndProcedure

&AtClient
Procedure CommodityGroupsCustomsValueOnChange(Item)
	
	CG_CalculationSettings = New Structure;
	CG_CalculationSettings.Insert("CalculateDutyAmount");
	CG_CalculationSettings.Insert("CalculateOtherDutyAmount");
	CG_CalculationSettings.Insert("CalculateVATAmount");
	
	Inv_CalculationSettings = New Structure;
	Inv_CalculationSettings.Insert("CalculateDutyAmount");
	Inv_CalculationSettings.Insert("CalculateOtherDutyAmount");
	Inv_CalculationSettings.Insert("CalculateExciseAmount");
	Inv_CalculationSettings.Insert("CalculateVATAmount");
	
	CommodityGroupsAmountsCalculations(CG_CalculationSettings, Inv_CalculationSettings);
	
EndProcedure

&AtClient
Procedure CommodityGroupsDutyRateOnChange(Item)
	
	CG_CalculationSettings = New Structure;
	CG_CalculationSettings.Insert("CalculateDutyAmount");
	CG_CalculationSettings.Insert("CalculateVATAmount");
	
	Inv_CalculationSettings = New Structure;
	Inv_CalculationSettings.Insert("CalculateDutyAmount");
	Inv_CalculationSettings.Insert("CalculateVATAmount");
	
	CommodityGroupsAmountsCalculations(CG_CalculationSettings, Inv_CalculationSettings);
	
EndProcedure

&AtClient
Procedure CommodityGroupsDutyAmountOnChange(Item)
	
	CG_CalculationSettings = New Structure;
	CG_CalculationSettings.Insert("CalculateDutyRate");
	CG_CalculationSettings.Insert("CalculateVATAmount");
	
	Inv_CalculationSettings = New Structure;
	Inv_CalculationSettings.Insert("CalculateDutyAmount");
	Inv_CalculationSettings.Insert("CalculateVATAmount");
	
	CommodityGroupsAmountsCalculations(CG_CalculationSettings, Inv_CalculationSettings);
	
EndProcedure

&AtClient
Procedure CommodityGroupsOtherDutyRateOnChange(Item)
	
	CG_CalculationSettings = New Structure;
	CG_CalculationSettings.Insert("CalculateOtherDutyAmount");
	CG_CalculationSettings.Insert("CalculateVATAmount");
	
	Inv_CalculationSettings = New Structure;
	Inv_CalculationSettings.Insert("CalculateOtherDutyAmount");
	Inv_CalculationSettings.Insert("CalculateVATAmount");
	
	CommodityGroupsAmountsCalculations(CG_CalculationSettings, Inv_CalculationSettings);
	
EndProcedure

&AtClient
Procedure CommodityGroupsOtherDutyAmountOnChange(Item)
	
	CG_CalculationSettings = New Structure;
	CG_CalculationSettings.Insert("CalculateOtherDutyRate");
	CG_CalculationSettings.Insert("CalculateVATAmount");
	
	Inv_CalculationSettings = New Structure;
	Inv_CalculationSettings.Insert("CalculateOtherDutyAmount");
	Inv_CalculationSettings.Insert("CalculateVATAmount");
	
	CommodityGroupsAmountsCalculations(CG_CalculationSettings, Inv_CalculationSettings);
	
EndProcedure

&AtClient
Procedure CommodityGroupsExciseAmountOnChange(Item)
	
	CG_CalculationSettings = New Structure;
	CG_CalculationSettings.Insert("CalculateVATAmount");
	
	Inv_CalculationSettings = New Structure;
	Inv_CalculationSettings.Insert("CalculateExciseAmount");
	Inv_CalculationSettings.Insert("CalculateVATAmount");
	
	CommodityGroupsAmountsCalculations(CG_CalculationSettings, Inv_CalculationSettings);
	
EndProcedure

&AtClient
Procedure CommodityGroupsVATRateOnChange(Item)
	
	CG_CalculationSettings = New Structure;
	CG_CalculationSettings.Insert("CalculateVATAmount");
	
	Inv_CalculationSettings = New Structure;
	Inv_CalculationSettings.Insert("CalculateVATAmount");
	
	CommodityGroupsAmountsCalculations(CG_CalculationSettings, Inv_CalculationSettings);
	
EndProcedure

#EndRegion

#Region FormTableEventHandlersOfInventoryTable

&AtClient
Procedure InventoryOnActivateRow(Item)
	
	InventoryRow = Item.CurrentData;
	
	If InventoryRow = Undefined Then
		
		CurrentProduct = Undefined;
		CurrentInvoice = Undefined;
		
	Else
		
		If Not InventoryRow.Products = CurrentProduct Then
			
			CurrentProduct = InventoryRow.Products;
			
			FillProductDependentChoiceLists(False);
			
		EndIf;
		
		If Not InventoryRow.StructuralUnit = CurrentInvoice Then
			
			CurrentInvoice = InventoryRow.Invoice;
			
			FillInvoiceDependentChoiceLists();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		
		CommodityGroupsRow = Items.CommodityGroups.CurrentData;
		
		If Not CommodityGroupsRow = Undefined Then
			
			InventoryRow = Item.CurrentData;
			
			InventoryRow.CommodityGroup = CommodityGroupsRow.CommodityGroup;
			InventoryRow.Origin = CommodityGroupsRow.Origin;
			
		EndIf;
		
	EndIf;
	
	If Not NewRow Or Clone Then
		Return;	
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;
	
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
Procedure InventoryProductsOnChange(Item)
	
	CurrentProduct = Items.Inventory.CurrentData.Products;
	
	FillProductDependentChoiceLists();
	
EndProcedure

&AtClient
Procedure InventoryCustomsValueOnChange(Item)
	
	CalculationSettings = New Structure;
	CalculationSettings.Insert("CalculateDutyAmount");
	CalculationSettings.Insert("CalculateOtherDutyAmount");
	CalculationSettings.Insert("CalculateVATAmount");
	
	InventoryAmountsCalculations(CalculationSettings);
	
EndProcedure

&AtClient
Procedure InventoryDutyAmountOnChange(Item)
	
	CalculationSettings = New Structure;
	CalculationSettings.Insert("CalculateVATAmount");
	
	InventoryAmountsCalculations(CalculationSettings);
	
EndProcedure

&AtClient
Procedure InventoryOtherDutyAmountOnChange(Item)
	
	CalculationSettings = New Structure;
	CalculationSettings.Insert("CalculateVATAmount");
	
	InventoryAmountsCalculations(CalculationSettings);
	
EndProcedure

&AtClient
Procedure InventoryExciseAmountOnChange(Item)
	
	CalculationSettings = New Structure;
	CalculationSettings.Insert("CalculateVATAmount");
	
	InventoryAmountsCalculations(CalculationSettings);
	
EndProcedure

&AtClient
Procedure InventoryInvoiceOnChange(Item)
	
	InventoryRow = Items.Inventory.CurrentData;
	
	CurrentInvoice = InventoryRow.Invoice;
	
	InvoiceData = GetInvoiceData(CurrentInvoice);
	
	FillInvoiceDependentChoiceLists(InvoiceData);
	
	InventoryRow.StructuralUnit = InvoiceData.StructuralUnit;
	If InventoryRow.AdvanceInvoicing <> InvoiceData.AdvanceInvoicing Then
		InventoryRow.AdvanceInvoicing = InvoiceData.AdvanceInvoicing;
		InventoryAdvanceInvoicingOnChangeAtClient(InventoryRow);
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryAdvanceInvoicingOnChange(Item)
	
	TabRow = Items.Inventory.CurrentData;
	InventoryAdvanceInvoicingOnChangeAtClient(TabRow);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ShowAll(Command)
	
	ShowAllItem = Items.ShowAll;
	
	ShowAllItem.Check = Not ShowAllItem.Check;
	
	ActivateCommodityGroup();
	
EndProcedure

&AtClient
Procedure AllocateCostsToInventory(Command)
	
	ClearMessages();
	
	ErrorText = "";
	
	If Object.CommodityGroups.Count() = 0 Or Object.Inventory.Count() = 0 Then
		ErrorText = NStr("en = 'Please create at least one commodity group and fill in the inventory.'; ru = 'Необходимо создать хотя бы одну группу номенклатуры и заполнить ее состав.';pl = 'Utwórz co najmniej jedną grupę towarów i wypełnij zapasy.';es_ES = 'Por favor, cree como mínimo un grupo de comodidad y rellenar el inventario.';es_CO = 'Por favor, cree como mínimo un grupo de comodidad y rellenar el inventario.';tr = 'Lütfen en az bir emtia grubu oluşturun ve stoğu doldurun.';it = 'Si prega di creare almeno un gruppo merceologico e compilarlo nelle scorte.';de = 'Bitte erstellen Sie mindestens eine Warengruppe und füllen Sie den Bestand aus.'");
		CommonClientServer.MessageToUser(ErrorText, , "Object.CommodityGroups");
		Return;
	EndIf;
	
	FilterStructure = New Structure("CommodityGroup");
	CGList = "";
	CGSelectedRows = Items.CommodityGroups.SelectedRows;
	
	For Each CommodityGroupsRowID In CGSelectedRows Do
		
		CommodityGroupsRow = Object.CommodityGroups.FindByID(CommodityGroupsRowID);
		
		CommodityGroup = Format(CommodityGroupsRow.CommodityGroup, "NZ=0; NG=0");
		CGList = CGList + ?(Not IsBlankString(CGList), ", ", "") + CommodityGroup;
		
		If CommodityGroupsRow.CustomsValue = 0. Then
			ErrorText = NStr("en = 'Please specify the customs value in the commodity group #%1.'; ru = 'Укажите таможенную стоимость в группе номенклатуры %1.';pl = 'Proszę podać wartość celną w grupie towarów nr %1.';es_ES = 'Por favor, especifique el valor aduanero en el grupo de comodidad #%1.';es_CO = 'Por favor, especifique el valor aduanero en el grupo de comodidad #%1.';tr = 'Lütfen #%1 emtia grubundaki gümrük değerini belirtin.';it = 'Si prega di specificare il valore doganale nel gruppo merceologico #%1.';de = 'Bitte geben Sie den Zollwert in der Warengruppe Nr %1 an.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, CommodityGroup);
			CustomsValueField = CommonClientServer.PathToTabularSection("Object.CommodityGroups", CommodityGroupsRow.LineNumber, "CustomsValue");
			CommonClientServer.MessageToUser(ErrorText, , CustomsValueField);
		EndIf;
		
		FilterStructure.CommodityGroup = CommodityGroupsRow.CommodityGroup;
		InventoryRows = Object.Inventory.FindRows(FilterStructure);
		
		If InventoryRows.Count() = 0 Then
			
			ErrorText = NStr("en = 'Please fill in the inventory of the commodity group #%1.'; ru = 'Укажите состав номенклатурной группы %1.';pl = 'Proszę wypełnić zapasy grupy towarów nr %1.';es_ES = 'Por favor, rellene el inventario del grupo de comodidad #%1.';es_CO = 'Por favor, rellene el inventario del grupo de comodidad #%1.';tr = 'Lütfen #%1 numaralı emtia grubunun stoğunu doldurun.';it = 'Si prega di compilarlo nelle scorte del gruppo merceologico #%1.';de = 'Bitte füllen Sie den Bestand der Warengruppe Nr %1 aus.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, CommodityGroup);
			CommonClientServer.MessageToUser(ErrorText, , "Object.Inventory");
			
		Else
			
			For Each InventoryRow In InventoryRows Do
				
				If InventoryRow.CustomsValue = 0 Then
					ErrorText = NStr("en = 'Please specify the customs value for the product in the line #%2 of the commodity group #%1.'; ru = 'Укажите таможенную стоимость номенклатуры в строке %2 состава номенклатурной группы %1.';pl = 'Proszę podać wartość celną produktu w wierszu nr %2 grupy towarów nr %1.';es_ES = 'Por favor, especifique el valor aduanero para el producto en la línea #%2 del grupo de comodidad #%1.';es_CO = 'Por favor, especifique el valor aduanero para el producto en la línea #%2 del grupo de comodidad #%1.';tr = 'Lütfen ürünün #%1 numaralı ürün grubunun #%2 numaralı satırındaki gümrük değerini belirtin.';it = 'Si prega di specificare il valore doganale per l''articolo nella linea #%2 del gruppo merceologico #%1.';de = 'Bitte geben Sie den Zollwert für das Produkt in der Zeile Nr %2 der Warengruppe Nr %1 an.'");
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, CommodityGroup, Format(InventoryRow.LineNumber, "NZ=0; NG=0"));
					CustomsValueField = CommonClientServer.PathToTabularSection("Object.Inventory", InventoryRow.LineNumber, "CustomsValue");
					CommonClientServer.MessageToUser(ErrorText, , CustomsValueField);
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	If ErrorText <> "" Or CGSelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	AllocateCostsToInventoryAtServer();
	
	RefreshFormFooter();
	
	NotificationText = ?(CGSelectedRows.Count() > 1,
		NStr("en = 'Customs fees of the commodity groups #%1 have been allocated.'; ru = 'Распределены таможенные сборы по группам номенклатуры %1.';pl = 'Opłaty celne dla grup towarów nr %1 zostały przydzielone.';es_ES = 'Comisiones aduaneras de los grupos de comodidad #%1 se han asignado.';es_CO = 'Comisiones aduaneras de los grupos de comodidad #%1 se han asignado.';tr = '#%1 emtia gruplarının gümrük ücretleri dağıtıldı.';it = 'I dazi doganali per i gruppi merceologici #%1 sono stati allocati.';de = 'Zollgebühren der Warengruppen Nr %1 wurden zugeteilt.'"),
		NStr("en = 'Customs fees of the commodity group #%1 have been allocated.'; ru = 'Распределены таможенные сборы по группе номенклатуры %1.';pl = 'Opłaty celne grupy towarów nr %1 zostały przydzielone.';es_ES = 'Comisiones aduaneras del grupo de comodidad #%1 se han asignado.';es_CO = 'Comisiones aduaneras del grupo de comodidad #%1 se han asignado.';tr = '#%1 emtia grubunun gümrük ücretleri dağıtıldı.';it = 'I dazi doganali per il gruppo merceologico #%1 sono stati allocati.';de = 'Zollgebühren der Warengruppe Nr %1 wurden zugeteilt.'"));
	ShowUserNotification(
		NStr("en = 'Done'; ru = 'Успешно';pl = 'Gotowe';es_ES = 'Hecho';es_CO = 'Hecho';tr = 'Bitti';it = 'Fatto';de = 'Erledigt'"), ,
		StringFunctionsClientServer.SubstituteParametersToString(NotificationText, CGList),
		PictureLib.Information32);
	
EndProcedure

&AtClient
Procedure FillCostsByInventory(Command)
	
	FilterStructure = New Structure("CommodityGroup");
	
	For Each CommodityGroupsRowID In Items.CommodityGroups.SelectedRows Do
		
		CommodityGroupsRow = Object.CommodityGroups.FindByID(CommodityGroupsRowID);
		
		If Not CommodityGroupsRow = Undefined Then
			
			FilterStructure.CommodityGroup = CommodityGroupsRow.CommodityGroup;
			
			InventoryRows = Object.Inventory.FindRows(FilterStructure);
			
			CommodityGroupsRow.CustomsValue = 0;
			CommodityGroupsRow.DutyAmount = 0;
			CommodityGroupsRow.OtherDutyAmount = 0;
			CommodityGroupsRow.ExciseAmount = 0;
			CommodityGroupsRow.VATAmount = 0;
			
			For Each InventoryRow In InventoryRows Do
				
				CommodityGroupsRow.CustomsValue		= CommodityGroupsRow.CustomsValue		+ InventoryRow.CustomsValue;
				CommodityGroupsRow.DutyAmount		= CommodityGroupsRow.DutyAmount			+ InventoryRow.DutyAmount;
				CommodityGroupsRow.OtherDutyAmount	= CommodityGroupsRow.OtherDutyAmount	+ InventoryRow.OtherDutyAmount;
				CommodityGroupsRow.ExciseAmount		= CommodityGroupsRow.ExciseAmount		+ InventoryRow.ExciseAmount;
				CommodityGroupsRow.VATAmount		= CommodityGroupsRow.VATAmount			+ InventoryRow.VATAmount;
				
			EndDo;
			
			CalculateDutyRate(CommodityGroupsRow);
			CalculateOtherDutyRate(CommodityGroupsRow);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure InventoryPickByInvoices(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ChoiceMode", True);
	ParametersStructure.Insert("MultipleChoice", True);
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Posted", True);
	FilterStructure.Insert("VATTaxation", PredefinedValue("Enum.VATTaxationTypes.ForExport"));
	FilterStructure.Insert("Company", Object.Company);
	FilterStructure.Insert("Counterparty", Object.Supplier);
	FilterStructure.Insert("Contract", Object.SupplierContract);
	
	ParametersStructure.Insert("Filter", FilterStructure);
	
	OpenForm("Document.SupplierInvoice.ChoiceForm", ParametersStructure, ThisObject);
	
EndProcedure

&AtClient
Procedure Pick(Command)
	
	DocumentPresentaion	= NStr("en = 'customs declaration'; ru = 'таможенная декларация';pl = 'deklaracja celna';es_ES = 'declaración de la aduana';es_CO = 'declaración de la aduana';tr = 'Gümrük beyannamesi';it = 'dichiarazione doganale';de = 'Zollerklärung'");
	
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, "Inventory", DocumentPresentaion, True, False, False);
	
	SelectionParameters.Insert("Company", Company);
	
	NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseSelection", ThisObject);
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region Internal

#Region CounterpartyAndContract

&AtServer
Function GetDataCounterpartyOnChange()
	
	ContractByDefault = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"Contract",
		ContractByDefault);
		
	StructureData.Insert(
		"SettlementsCurrency",
		Common.ObjectAttributeValue(ContractByDefault, "SettlementsCurrency"));
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Object.Date, StructureData.SettlementsCurrency, Object.Company));
	
	IsSupplier = Common.ObjectAttributeValue(Object.Counterparty, "Supplier");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", True);
		ParametersStructure.Insert("FillHeader", True);
		ParametersStructure.Insert("FillInventory", False);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;

	SetContractVisible();
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, OperationKind)
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	If Not ValueIsFilled(Counterparty) Then
		Return ManagerOfCatalog.EmptyRef();
	EndIf;
	
	Return DriveServer.GetContractByDefault(Document, Counterparty, Company, OperationKind);
	
EndFunction

&AtServer
Procedure SetContractVisible()
	
	If ValueIsFilled(Object.Counterparty) Then
		
		Items.Contract.Visible = Common.ObjectAttributeValue(Object.Counterparty, "DoOperationsByContracts");
		
	Else
		
		Items.Contract.Visible = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessContractChange()
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
	
	If ContractBeforeChange <> Object.Contract Then
		
		ProcessContractChangeFragment(ContractBeforeChange);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessContractChangeFragment(ContractBeforeChange, StructureData = Undefined)
	
	If StructureData = Undefined Then
		StructureData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
	EndIf;
	
	SettlementsCurrency = StructureData.SettlementsCurrency;
	
	AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
		Object.DocumentCurrency,
		Object.ExchangeRate,
		Object.Multiplicity);
	
	If ValueIsFilled(Object.Contract) Then 
		Object.ExchangeRate = ?(StructureData.SettlementsCurrencyRateRepetition.Rate = 0, 1, StructureData.SettlementsCurrencyRateRepetition.Rate);
		Object.Multiplicity = ?(StructureData.SettlementsCurrencyRateRepetition.Repetition = 0, 1, StructureData.SettlementsCurrencyRateRepetition.Repetition);
		Object.ContractCurrencyExchangeRate = Object.ExchangeRate;
		Object.ContractCurrencyMultiplicity = Object.Multiplicity;
	EndIf;
	
	OpenFormPricesAndCurrencies = ValueIsFilled(Object.Contract)
		AND ValueIsFilled(SettlementsCurrency)
		AND Object.DocumentCurrency <> StructureData.SettlementsCurrency
		AND (Object.Inventory.Count() > 0 OR Object.CommodityGroups.Count() > 0);
	
	If ValueIsFilled(SettlementsCurrency) Then
		Object.DocumentCurrency = SettlementsCurrency;
	EndIf;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = MessagesToUserClientServer.GetSettleCurrencyOnChangeWarningText();
		
		ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange, True, False, WarningText);
		
	Else
		
		GenerateLabelPricesAndCurrency();
		
	EndIf;
	
	RefreshFormFooter();
	
EndProcedure

&AtServer
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", True);
		ParametersStructure.Insert("FillHeader", True);
		ParametersStructure.Insert("FillInventory", False);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"SettlementsCurrency",
		Common.ObjectAttributeValue(Contract, "SettlementsCurrency"));
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Date, StructureData.SettlementsCurrency, Object.Company));
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetContractChoiceFormParameters(Document, Company, Counterparty, Contract, OperationKind)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document, OperationKind);
	
	FormParameters = New Structure;
	If ValueIsFilled(Counterparty) Then
		FormParameters.Insert("ControlContractChoice", Common.ObjectAttributeValue(Counterparty, "DoOperationsByContracts"));
	Else
		FormParameters.Insert("ControlContractChoice", False);
	EndIf;
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

#EndRegion

&AtClient
Procedure SetCounterpartyProperties()
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCustomsDeclaration.Customs") Then
		Items.Counterparty.Title = NStr("en = 'Customs'; ru = 'Таможня';pl = 'Urząd celny';es_ES = 'Aduana';es_CO = 'Aduana';tr = 'Gümrük';it = 'Dogana';de = 'Zoll'");
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCustomsDeclaration.Broker") Then
		Items.Counterparty.Title = NStr("en = 'Customs broker'; ru = 'Брокеру';pl = 'Agent celny';es_ES = 'Agente aduanero';es_CO = 'Agente aduanero';tr = 'Gümrük komisyoncusu';it = 'Broker doganale';de = 'Zollagent'");
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesCustomsDeclaration.CustomsBroker") Then
		Items.Counterparty.Title = NStr("en = 'Customs/Customs broker'; ru = 'Таможня/Брокер';pl = 'Urząd/agent celny';es_ES = 'Aduana/Agente aduanero';es_CO = 'Aduana/Agente aduanero';tr = 'Gümrük/Gümrük komisyoncusu';it = 'Dogana/Broker doganale';de = 'Zoll/Zollagent'");
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesCustomsDeclaration.Broker") Then
		
		NewParameter = New ChoiceParameter("Filter.Supplier", True);
		If Not IsSupplier Then
			Object.Counterparty = Undefined;
			Object.Contract = Undefined;
			IsSupplier = True;
		EndIf;
			
	Else
		
		NewParameter = New ChoiceParameter("Filter.OtherRelationship", True);
		If IsSupplier Then
			Object.Counterparty = Undefined;
			Object.Contract = Undefined;
			IsSupplier = False;
		EndIf;
		
	EndIf;
	
	NewArray = New Array();
	NewArray.Add(NewParameter);
	NewParameters = New FixedArray(NewArray);
	Items.Counterparty.ChoiceParameters = NewParameters;

EndProcedure

#Region SupplierAndSupplierContract

&AtClient
Function InventoryWillBeClearedMessageText()
	
	Return NStr("en = 'Inventory tab will be cleared. Do you want to continue?'; ru = 'Закладка с номенклатурой будет очищена, продолжить?';pl = 'Tab Produkcji zostanie wyczyszczona. Czy chcesz kontynuować?';es_ES = 'Pestaña del inventario se eliminará. ¿Quiere continuar?';es_CO = 'Pestaña del inventario se eliminará. ¿Quiere continuar?';tr = 'Stok sekmesi silinecek. Devam etmek istiyor musunuz?';it = 'La scheda scorte sarà cancellate. Volete continuare?';de = 'Die Registerkarte Bestand wird gelöscht. Möchten Sie fortsetzen?'");
	
EndFunction

&AtClient
Procedure SupplierChangeQueryBoxProcessing(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Object.CommodityGroups.Clear();
		Object.Inventory.Clear();
		InitializeInventoryCommodityGroupChoiceList(Items.InventoryCommodityGroup, Object.CommodityGroups);
		RefreshFormFooter();
		
		SupplierChangeProcessing();
		
	Else
		
		Object.Supplier = Supplier;
		Object.SupplierContract = SupplierContract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SupplierChangeProcessing()
	
	Supplier = Object.Supplier;
	
	StructureData = GetDataSupplierOnChange(Object.Date, Object.DocumentCurrency, Object.Supplier, Object.Company);
	
	Object.SupplierContract = StructureData.SupplierContract;
	SupplierContract = Object.SupplierContract;
	
EndProcedure

&AtServer
Function GetDataSupplierOnChange(Date, DocumentCurrency, Supplier, Company)
	
	SupplierContractByDefault = GetSupplierContractByDefault(Documents.SupplierInvoice.EmptyRef(), Supplier, Company);
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"SupplierContract",
		SupplierContractByDefault);
		
	StructureData.Insert(
		"SettlementsCurrency",
		Common.ObjectAttributeValue(SupplierContractByDefault, "SettlementsCurrency"));
	
	SetSupplierContractVisible();
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetSupplierContractByDefault(Document, Supplier, Company)
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	If Not ValueIsFilled(Supplier) Then
		Return ManagerOfCatalog.EmptyRef();
	EndIf;
	
	SupplierData = Common.ObjectAttributesValues(Supplier, "DoOperationsByContracts, ContractByDefault");
	
	If Not SupplierData.DoOperationsByContracts Then
		Return SupplierData.ContractByDefault;
	EndIf;
	
	SupplierContractTypesList = ManagerOfCatalog.GetContractTypesListForDocument(Document);
	SupplierContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Supplier, Company, SupplierContractTypesList);
	
	Return SupplierContractByDefault;
	
EndFunction

&AtServer
Procedure SetSupplierContractVisible()
	
	If ValueIsFilled(Object.Supplier) Then
		
		Items.SupplierContract.Visible = Common.ObjectAttributeValue(Object.Supplier, "DoOperationsByContracts");
		
	Else
		
		Items.SupplierContract.Visible = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SupplierContractChangeQueryBoxProcessing(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Object.CommodityGroups.Clear();
		Object.Inventory.Clear();
		InitializeInventoryCommodityGroupChoiceList(Items.InventoryCommodityGroup, Object.CommodityGroups);
		RefreshFormFooter();
		
		ProcessSupplierContractChange();
		
	Else
		
		Object.SupplierContract = SupplierContract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessSupplierContractChange()
	
	SupplierContract = Object.SupplierContract;
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", True);
		ParametersStructure.Insert("FillHeader", True);
		ParametersStructure.Insert("FillInventory", False);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetSupplierContractChoiceFormParameters(Document, Company, Supplier, SupplierContract)
	
	SupplierContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Document);
	
	FormParameters = New Structure;
	If ValueIsFilled(Supplier) Then
		FormParameters.Insert("ControlContractChoice", Common.ObjectAttributeValue(Supplier, "DoOperationsByContracts"));
	Else
		FormParameters.Insert("ControlContractChoice", False);
	EndIf;
	FormParameters.Insert("Counterparty", Supplier);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractType", SupplierContractTypesList);
	FormParameters.Insert("CurrentRow", SupplierContract);
	
	Return FormParameters;
	
EndFunction

#EndRegion

#Region PricesAndCurrency

&AtServer
Procedure GenerateLabelPricesAndCurrency()
	
	LabelStructure = New Structure;
	LabelStructure.Insert("ForeignExchangeAccounting",	ForeignExchangeAccounting);
	LabelStructure.Insert("DocumentCurrency",			Object.DocumentCurrency);
	LabelStructure.Insert("ExchangeRate",				Object.ExchangeRate);
	LabelStructure.Insert("SettlementsCurrency",		SettlementsCurrency);
	LabelStructure.Insert("RateNationalCurrency",		RateNationalCurrency);
	
	PricesAndCurrency = DriveClientServer.GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(AttributesBeforeChange = Undefined, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	If AttributesBeforeChange = Undefined Then
		AttributesBeforeChange = New Structure("DocumentCurrency, ExchangeRate, Multiplicity",
			Object.DocumentCurrency,
			Object.ExchangeRate,
			Object.Multiplicity);
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",				Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate",					Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",					Object.Multiplicity);
	ParametersStructure.Insert("Counterparty",					Object.Counterparty);
	ParametersStructure.Insert("Contract",						Object.Contract);
	ParametersStructure.Insert("ContractCurrencyExchangeRate",	Object.ContractCurrencyExchangeRate);
	ParametersStructure.Insert("ContractCurrencyMultiplicity",	Object.ContractCurrencyMultiplicity);
	ParametersStructure.Insert("Company",						Company);
	ParametersStructure.Insert("DocumentDate",					Object.Date);
	ParametersStructure.Insert("RefillPrices",					False);
	ParametersStructure.Insert("RecalculatePrices",				False);
	ParametersStructure.Insert("WereMadeChanges",				False);
	ParametersStructure.Insert("WarningText",					WarningText);
	
	NotifyDescription = New NotifyDescription("ProcessChangesOnButtonPricesAndCurrenciesEnd",
		ThisObject,
		AttributesBeforeChange);
	
	OpenForm("CommonForm.PricesAndCurrency",
		ParametersStructure, ThisObject,,,,
		NotifyDescription,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrenciesEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") And ClosingResult.WereMadeChanges Then
		
		RatesStructure = New Structure;
		RatesStructure.Insert("ExchangeRate", ClosingResult.ExchangeRate);
		RatesStructure.Insert("Multiplicity", ClosingResult.Multiplicity);
		RatesStructure.Insert("InitRate", AdditionalParameters.ExchangeRate);
		RatesStructure.Insert("RepetitionBeg", AdditionalParameters.Multiplicity);
		
		Object.DocumentCurrency				= ClosingResult.DocumentCurrency;
		Object.ExchangeRate					= ClosingResult.ExchangeRate;
		Object.Multiplicity					= ClosingResult.Multiplicity;
		Object.ContractCurrencyExchangeRate	= ClosingResult.SettlementsRate;
		Object.ContractCurrencyMultiplicity	= ClosingResult.SettlementsMultiplicity;
		
		If ClosingResult.RecalculatePrices Then
			
			RecalculateAmountsOfATabularSection(Object.CommodityGroups, RatesStructure);
			RecalculateAmountsOfATabularSection(Object.Inventory, RatesStructure);
			
		EndIf;
		
	EndIf;
	
	GenerateLabelPricesAndCurrency();
	
	RefreshFormFooter();
	
EndProcedure

&AtClient
Procedure RecalculateAmountsOfATabularSection(TabularSection, RatesStructure)
	
	AmountFieldsToBeRecalculated = New Array;
	AmountFieldsToBeRecalculated.Add("CustomsValue");
	AmountFieldsToBeRecalculated.Add("DutyAmount");
	AmountFieldsToBeRecalculated.Add("OtherDutyAmount");
	AmountFieldsToBeRecalculated.Add("ExciseAmount");
	AmountFieldsToBeRecalculated.Add("VATAmount");
	
	For Each TabularSectionRow In TabularSection Do
		
		For Each AmountField In AmountFieldsToBeRecalculated Do
			
			TabularSectionRow[AmountField] = DriveServer.RecalculateFromCurrencyToCurrency(
				TabularSectionRow[AmountField],
				GetExchangeRateMethod(Object.Company),
				RatesStructure.InitRate, 
				RatesStructure.ExchangeRate, 
				RatesStructure.RepetitionBeg, 
				RatesStructure.Multiplicity);
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetExchangeRateMethod(Company)

	Return DriveServer.GetExchangeMethod(Company);	

EndFunction

&AtClient
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	CurrencyRateRepetition = StructureData.CurrencyRateRepetition;
	SettlementsCurrencyRateRepetition = StructureData.SettlementsCurrencyRateRepetition;
	
	NewExchangeRate	= ?(CurrencyRateRepetition.Rate = 0, 1, CurrencyRateRepetition.Rate);
	NewRatio		= ?(CurrencyRateRepetition.Repetition = 0, 1, CurrencyRateRepetition.Repetition);
	
	NewContractCurrencyExchangeRate = ?(SettlementsCurrencyRateRepetition.Rate = 0,
		1,
		SettlementsCurrencyRateRepetition.Rate);
	
	NewContractCurrencyRatio = ?(SettlementsCurrencyRateRepetition.Repetition = 0,
		1,
		SettlementsCurrencyRateRepetition.Repetition);
	
	If Object.ExchangeRate <> NewExchangeRate
		Or Object.Multiplicity <> NewRatio
		Or Object.ContractCurrencyExchangeRate <> NewContractCurrencyExchangeRate
		Or Object.ContractCurrencyMultiplicity <> NewContractCurrencyRatio Then
		
		QuestionText = MessagesToUserClientServer.GetApplyRatesOnNewDateQuestionText();
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("NewExchangeRate",					NewExchangeRate);
		AdditionalParameters.Insert("NewRatio",							NewRatio);
		AdditionalParameters.Insert("NewContractCurrencyExchangeRate",	NewContractCurrencyExchangeRate);
		AdditionalParameters.Insert("NewContractCurrencyRatio",			NewContractCurrencyRatio);
		
		NotifyDescription = New NotifyDescription("RecalculateExchangeRatesEnd", ThisObject, AdditionalParameters);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecalculateExchangeRatesEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		Object.ContractCurrencyExchangeRate = AdditionalParameters.NewContractCurrencyExchangeRate;
		Object.ContractCurrencyMultiplicity = AdditionalParameters.NewContractCurrencyRatio;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Other

&AtServer
Procedure OnCreateOnReadCommonActions()
	
	FillFormAttributesValues();
	
	GenerateLabelPricesAndCurrency();

	InitializeInventoryCommodityGroupChoiceList(Items.InventoryCommodityGroup, Object.CommodityGroups);
	
	Items.Inventory.RowFilter = New FixedStructure("CommodityGroup", 0);
	
	SetContractVisible();
	SetSupplierContractVisible();
	SetGroupExpensesItemsVisible();
	SetProjectVisible();
	
EndProcedure

&AtServer
Procedure FillFormAttributesValues()
	
	Date						= Object.Date;
	Company						= Object.Company;
	Counterparty				= Object.Counterparty;
	Contract					= Object.Contract;
	Supplier					= Object.Supplier;
	SupplierContract			= Object.SupplierContract;
	SettlementsCurrency			= Common.ObjectAttributeValue(Object.Contract, "SettlementsCurrency");
	FunctionalCurrency			= Constants.FunctionalCurrency.Get();
	StructureByCurrency			= CurrencyRateOperations.GetCurrencyRate(Object.Date, FunctionalCurrency, Object.Company);
	RateNationalCurrency		= StructureByCurrency.Rate;
	RepetitionNationalCurrency	= StructureByCurrency.Repetition;
	ForeignExchangeAccounting	= Constants.ForeignExchangeAccounting.Get();
	
	AccountingPolicy = GetAccountingPolicyValues(Date, Company);
	RegisteredForVAT = AccountingPolicy.RegisteredForVAT;
	
	SetVATIsDueChoiceList(Items.VATIsDue, RegisteredForVAT);
	
EndProcedure

&AtServer
Procedure SetGroupExpensesItemsVisible()
	
	Items.GroupExpensesItems.Visible = Object.OtherDutyToExpenses;
	
	SetProjectVisible();
	
EndProcedure

&AtClient
Procedure CompanyChangeQueryBoxProcessing(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Object.CommodityGroups.Clear();
		Object.Inventory.Clear();
		InitializeInventoryCommodityGroupChoiceList(Items.InventoryCommodityGroup, Object.CommodityGroups);
		RefreshFormFooter();
		
		CompanyChangeProcessing();
		
	Else
		
		Object.Company = Company;
		Object.Contract = Contract;
		Object.SupplierContract = SupplierContract;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CompanyChangeProcessing()
	
	Object.Number = "";
	Company = Object.Company;
	
	DataCompanyOnChange = GetDataCompanyOnChange(Object.Date, Object.Company, Object.Ref, Object.Counterparty,
		Object.Supplier, Object.OperationKind);
	
	Object.SupplierContract = DataCompanyOnChange.SupplierContract;
	ProcessSupplierContractChange();
	
	Object.Contract = DataCompanyOnChange.Contract;
	ProcessContractChange();
	
	If RegisteredForVAT <> DataCompanyOnChange.RegisteredForVAT Then
		
		RegisteredForVAT = DataCompanyOnChange.RegisteredForVAT;
		
		SetVATIsDueChoiceList(Items.VATIsDue, RegisteredForVAT);
		
		ValidateVATIsDueValue();
		
	EndIf;
	
	GenerateLabelPricesAndCurrency();
	
EndProcedure

&AtServer
Function GetDataCompanyOnChange(Date, Company, Ref, Counterparty, Supplier, OperationKind)
	
	ProcessingCompanyVATNumbers(False);
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", True);
		ParametersStructure.Insert("FillHeader", True);
		ParametersStructure.Insert("FillInventory", True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	DataCompanyOnChange = New Structure;
	
	SupplierContract = GetSupplierContractByDefault(
		PredefinedValue("Document.SupplierInvoice.EmptyRef"),
		Supplier,
		Company);
	
	DataCompanyOnChange.Insert("SupplierContract", SupplierContract);
	
	Contract = GetContractByDefault(Ref, Counterparty, Company, OperationKind);
	
	DataCompanyOnChange.Insert("Contract", Contract);
	
	RegisteredForVAT = GetAccountingPolicyValues(Date, Company).RegisteredForVAT;
	DataCompanyOnChange.Insert("RegisteredForVAT", RegisteredForVAT);
	
	Return DataCompanyOnChange;
	
EndFunction

&AtClient
Procedure Attachable_DateChangeProcessing()
	
	DataDateOnChange = GetDataDateOnChange(Object.Date, Object.Company, Object.DocumentCurrency);
	
	If ValueIsFilled(SettlementsCurrency) Then
		RecalculateExchangeRateMultiplicitySettlementCurrency(DataDateOnChange);
	EndIf;
	
	If RegisteredForVAT <> DataDateOnChange.RegisteredForVAT Then
		
		RegisteredForVAT = DataDateOnChange.RegisteredForVAT;
		
		SetVATIsDueChoiceList(Items.VATIsDue, RegisteredForVAT);
		
		ValidateVATIsDueValue();
		
	EndIf;
	
	Date = Object.Date;
	
EndProcedure

&AtServer
Function GetDataDateOnChange(Date, Company, DocumentCurrency)
	
	DataCompanyOnChange = New Structure;
	
	RegisteredForVAT = GetAccountingPolicyValues(Date, Company).RegisteredForVAT;
	DataCompanyOnChange.Insert("RegisteredForVAT", RegisteredForVAT);
	
	ProcessingCompanyVATNumbers();
	GenerateLabelPricesAndCurrency();
	
	CurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Date, DocumentCurrency, Company);
	DataCompanyOnChange.Insert("CurrencyRateRepetition", CurrencyRateRepetition);
	
	If DocumentCurrency <> SettlementsCurrency Then
		SettlementsCurrencyRateRepetition = CurrencyRateOperations.GetCurrencyRate(Date, SettlementsCurrency, Company);
		DataCompanyOnChange.Insert("SettlementsCurrencyRateRepetition", SettlementsCurrencyRateRepetition);
	Else
		DataCompanyOnChange.Insert("SettlementsCurrencyRateRepetition", CurrencyRateRepetition);
	EndIf;
	
	Return DataCompanyOnChange;
	
EndFunction

&AtServerNoContext
Function GetAccountingPolicyValues(Date, Company)

	Return InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	
EndFunction

&AtServer
Procedure ProcessingCompanyVATNumbers(FillOnlyEmpty = True)
	WorkWithVAT.ProcessingCompanyVATNumbers(Object, Items.CompanyVATNumber, FillOnlyEmpty);	
EndProcedure

&AtClientAtServerNoContext
Procedure SetVATIsDueChoiceList(ItemVATIsDue, RegisteredForVAT)
	
	VATIsDueChoiceList = ItemVATIsDue.ChoiceList;
	VATIsDueChoiceList.Clear();
	
	VATIsDueChoiceList.Add(PredefinedValue("Enum.VATDueOnCustomsClearance.OnTheSupply"));
	
	If RegisteredForVAT Then
		
		VATIsDueChoiceList.Add(PredefinedValue("Enum.VATDueOnCustomsClearance.InTheVATReturn"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ValidateVATIsDueValue()
	
	If Not RegisteredForVAT Then
		
		VATDueOnTheSupply = PredefinedValue("Enum.VATDueOnCustomsClearance.OnTheSupply");
		
		If Object.VATIsDue <> VATDueOnTheSupply Then
			
			Object.VATIsDue = VATDueOnTheSupply;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshFormFooter()
	
	Object.CustomsValue		= Object.Inventory.Total("CustomsValue");
	Object.DutyAmount		= Object.Inventory.Total("DutyAmount");
	Object.OtherDutyAmount	= Object.Inventory.Total("OtherDutyAmount");
	Object.ExciseAmount		= Object.Inventory.Total("ExciseAmount");
	Object.VATAmount		= Object.Inventory.Total("VATAmount");
	Object.DocumentAmount	= Object.DutyAmount + Object.OtherDutyAmount + Object.ExciseAmount + Object.VATAmount;
	
EndProcedure

&AtClient
Procedure FillInvoiceDependentChoiceLists(InvoiceData = Undefined)
	
	StructuralUnitChoiceList = Items.InventoryStructuralUnit.ChoiceList;
	StructuralUnitChoiceList.Clear();
	
	If ValueIsFilled(CurrentInvoice) Then
		
		If InvoiceData = Undefined Then
			InvoiceData = GetInvoiceData(CurrentInvoice);
		EndIf;
		
		If ValueIsFilled(InvoiceData.StructuralUnit) Then
			StructuralUnitChoiceList.Add(InvoiceData.StructuralUnit);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetInvoiceData(Invoice)
	
	Result = Common.ObjectAttributesValues(Invoice, "StructuralUnit, OperationKind");
	
	IsAdvanceInvoicing = (Result.OperationKind = Enums.OperationTypesSupplierInvoice.AdvanceInvoice);
	
	Result.Insert("AdvanceInvoicing", IsAdvanceInvoicing);
	
	Return Result;
	
EndFunction

&AtClient
Procedure FillProductDependentChoiceLists(GetGLAccounts = True)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	OriginChoiceList = Items.InventoryOrigin.ChoiceList;
	OriginChoiceList.Clear();
	
	HSCodeChoiceList = Items.InventoryHSCode.ChoiceList;
	HSCodeChoiceList.Clear();
	
	If ValueIsFilled(CurrentProduct) Then
		
		StructureData = New Structure;
		StructureData.Insert("TabName", "Inventory");
		StructureData.Insert("Object", Object);
		StructureData.Insert("Products", CurrentProduct);
		StructureData.Insert("GetGLAccounts", UseDefaultTypeOfAccounting And GetGLAccounts);
		
		If UseDefaultTypeOfAccounting Then
			AddGLAccountsToStructure(ThisObject, "Inventory", StructureData);
		EndIf;
		
		StructureData = GetProductData(StructureData);
		ProductData = StructureData.ProductData;
		
		FillPropertyValues(TabularSectionRow, StructureData); 
		
		If ValueIsFilled(ProductData.CountryOfOrigin) Then
			
			OriginChoiceList.Add(ProductData.CountryOfOrigin);
			
		EndIf;
		
		If ValueIsFilled(ProductData.HSCode) Then
			
			HSCodeChoiceList.Add(ProductData.HSCode);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetProductData(StructureData)
	
	If StructureData.GetGLAccounts Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	StructureData.Insert("ProductData", Common.ObjectAttributesValues(StructureData.Products, "CountryOfOrigin, HSCode"));
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure AllocateCostsToInventoryAtServer()
	
	FilterStructure = New Structure("CommodityGroup");
	CGSelectedRows = Items.CommodityGroups.SelectedRows;
	
	For Each CommodityGroupsRowID In CGSelectedRows Do
		
		CommodityGroupsRow = Object.CommodityGroups.FindByID(CommodityGroupsRowID);
		
		FilterStructure.CommodityGroup = CommodityGroupsRow.CommodityGroup;
		
		InventoryRows = Object.Inventory.Unload(FilterStructure);
		
		If InventoryRows.Count() > 0 Then
			
			Coefficients = InventoryRows.UnloadColumn("CustomsValue");
			
			AmountNames = StringFunctionsClientServer.SplitStringIntoWordArray("CustomsValue, DutyAmount, OtherDutyAmount, ExciseAmount, VATAmount");
			
			For Each AmountName In AmountNames Do
			
				NewAmounts = CommonClientServer.DistributeAmountInProportionToCoefficients(CommodityGroupsRow[AmountName], Coefficients);
				If NewAmounts = Undefined Then
					
					InventoryRows.FillValues(0, AmountName);
					
				Else
					
					InventoryRows.LoadColumn(NewAmounts, AmountName);
				EndIf;
				
			EndDo;
			
			For Each InventoryRow In InventoryRows Do
				FillPropertyValues(Object.Inventory[InventoryRow.LineNumber - 1], InventoryRow);
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			GetInventoryFromStorage(InventoryAddressInStorage, CurrentCommodityGroup);
			
			RefreshFormFooter();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, CommodityGroup)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object.Inventory.Add();
		FillPropertyValues(NewRow, ImportRow);
		
		If UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure ProcessInvoicesSelection(SelectedInvoices)
	
	DocObject = FormAttributeToValue("Object");
	
	DocObject.FillBySupplierInvoice(New Structure("ArrayOfSupplierInvoices", SelectedInvoices));
	
	ValueToFormAttribute(DocObject, "Object");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillHeader", False);
		ParametersStructure.Insert("FillInventory", True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure VATIsDueOnChangeAtServer()
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", True);
		ParametersStructure.Insert("FillHeader", False);
		ParametersStructure.Insert("FillInventory", True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region CommodityGroups

&AtClient
Function NewCommodityGroup()
	
	MaxCommodityGroup = 0;
	
	For Each CommodityGroupRow In Object.CommodityGroups Do
		
		If CommodityGroupRow.CommodityGroup > MaxCommodityGroup Then
			
			MaxCommodityGroup = CommodityGroupRow.CommodityGroup;
			
		EndIf;
		
	EndDo;
	
	Return MaxCommodityGroup + 1;
	
EndFunction

&AtClient
Procedure ActivateCommodityGroup()
	
	ShowAll = Items.ShowAll.Check;
	InventoryItem = Items.Inventory;
	
	If Not ShowAll And (InventoryItem.RowFilter = Undefined Or InventoryItem.RowFilter.CommodityGroup <> CurrentCommodityGroup) Then
		
		InventoryItem.RowFilter = New FixedStructure("CommodityGroup", CurrentCommodityGroup);
		
	ElsIf ShowAll And InventoryItem.RowFilter <> Undefined Then
		
		InventoryItem.RowFilter = Undefined;
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure InitializeInventoryCommodityGroupChoiceList(ItemInventoryCommodityGroup, ObjectCommodityGroups)
	
	ICGChoiceList = ItemInventoryCommodityGroup.ChoiceList;
	
	ICGChoiceList.Clear();
	
	For Each CGRow In ObjectCommodityGroups Do
		
		ICGChoiceList.Add(CGRow.CommodityGroup);
		
	EndDo;
	
	ICGChoiceList.Add(0, "-");
	
	ICGChoiceList.SortByValue();
	
EndProcedure

&AtClient
Procedure ModifyInventoryCommodityGroupChoiceList(ValueToBeRemoved, ValueToBeAdded)
	
	ICGChoiceList = Items.InventoryCommodityGroup.ChoiceList;
	
	If Not ValueToBeRemoved = Undefined Then
		
		ICGChoiceListItem = ICGChoiceList.FindByValue(ValueToBeRemoved);
		
		If Not ICGChoiceListItem = Undefined Then
			
			ICGChoiceList.Delete(ICGChoiceListItem);
			
		EndIf;
		
	EndIf;
	
	If Not ValueToBeAdded = Undefined Then
		
		ICGChoiceList.Add(ValueToBeAdded);
		
	EndIf;
	
	ICGChoiceList.SortByValue();
	
EndProcedure

#EndRegion

#Region AmountsAndRatesCalculation

&AtClient
Procedure CalculateDutyAmount(TableRow, DutyRate)
	
	TableRow.DutyAmount = TableRow.CustomsValue * DutyRate / 100;
	
EndProcedure

&AtClient
Procedure CalculateDutyRate(TableRow)
	
	If Not TableRow.CustomsValue = 0 Then
		
		TableRow.DutyRate = 100 * TableRow.DutyAmount / TableRow.CustomsValue;
		
	Else
		
		TableRow.DutyRate = 0;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateOtherDutyAmount(TableRow, OtherDutyRate)
	
	TableRow.OtherDutyAmount = TableRow.CustomsValue * OtherDutyRate / 100;
	
EndProcedure

&AtClient
Procedure CalculateOtherDutyRate(TableRow)
	
	If Not TableRow.CustomsValue = 0 Then
		
		TableRow.OtherDutyRate = 100 * TableRow.OtherDutyAmount / TableRow.CustomsValue;
		
	Else
		
		TableRow.OtherDutyRate = 0;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateExciseAmount(TableRow, CustomsValue, ExciseAmount)
	
	If CustomsValue = 0 Or ExciseAmount = 0 Then
		
		TableRow.ExciseAmount = 0;
		
	Else
		
		TableRow.ExciseAmount = TableRow.CustomsValue * ExciseAmount / CustomsValue;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateVATAmount(TableRow, VATRate)
	
	If TypeOf(VATRate) = Type("CatalogRef.VATRates") Then
		
		VATRateValue = DriveReUse.GetVATRateValue(VATRate);
		
	Else
		
		VATRateValue = VATRate;
		
	EndIf;
	
	TableRow.VATAmount = (TableRow.CustomsValue + TableRow.DutyAmount + TableRow.OtherDutyAmount + TableRow.ExciseAmount) * VATRateValue / 100;
	
EndProcedure

&AtClient
Procedure InventoryAmountsCalculations(CalculationSettings)
	
	CommodityGroupsRow = Items.CommodityGroups.CurrentData;
	
	If Not CommodityGroupsRow = Undefined Then
		
		InventoryRow = Items.Inventory.CurrentData;
		
		If CalculationSettings.Property("CalculateDutyAmount") Then
			
			CalculateDutyAmount(InventoryRow, CommodityGroupsRow.DutyRate);
			
		EndIf;
		
		If CalculationSettings.Property("CalculateOtherDutyAmount") Then
			
			CalculateOtherDutyAmount(InventoryRow, CommodityGroupsRow.OtherDutyRate);
			
		EndIf;
		
		If CalculationSettings.Property("CalculateVATAmount") Then
			
			CalculateVATAmount(InventoryRow, CommodityGroupsRow.VATRate);
			
		EndIf;
		
		RefreshFormFooter();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommodityGroupsAmountsCalculations(CG_CalculationSettings, Inv_CalculationSettings)
	
	CommodityGroupsRow = Items.CommodityGroups.CurrentData;
	
	VATRateValue = DriveReUse.GetVATRateValue(CommodityGroupsRow.VATRate);
	
	If CG_CalculationSettings.Property("CalculateDutyRate") Then
		CalculateDutyRate(CommodityGroupsRow);
	EndIf;
	
	If CG_CalculationSettings.Property("CalculateDutyAmount") Then
		CalculateDutyAmount(CommodityGroupsRow, CommodityGroupsRow.DutyRate);
	EndIf;
	
	If CG_CalculationSettings.Property("CalculateOtherDutyRate") Then
		CalculateOtherDutyRate(CommodityGroupsRow);
	EndIf;
	
	If CG_CalculationSettings.Property("CalculateOtherDutyAmount") Then
		CalculateOtherDutyAmount(CommodityGroupsRow, CommodityGroupsRow.OtherDutyRate);
	EndIf;
	
	If CG_CalculationSettings.Property("CalculateVATAmount") Then
		CalculateVATAmount(CommodityGroupsRow, VATRateValue);
	EndIf;
	
	InventoryRows = Object.Inventory.FindRows(New Structure("CommodityGroup", CurrentCommodityGroup));
	
	For Each InventoryRow In InventoryRows Do
		
		If Inv_CalculationSettings.Property("CalculateDutyAmount") Then
			CalculateDutyAmount(InventoryRow, CommodityGroupsRow.DutyRate);
		EndIf;
		
		If Inv_CalculationSettings.Property("CalculateOtherDutyAmount") Then
			CalculateOtherDutyAmount(InventoryRow, CommodityGroupsRow.OtherDutyRate);
		EndIf;
		
		If Inv_CalculationSettings.Property("CalculateExciseAmount") Then
			CalculateExciseAmount(InventoryRow, CommodityGroupsRow.CustomsValue, CommodityGroupsRow.ExciseAmount);
		EndIf;
		
		If Inv_CalculationSettings.Property("CalculateVATAmount") Then
			CalculateVATAmount(InventoryRow, VATRateValue);
		EndIf;
		
	EndDo;
	
	RefreshFormFooter();
	
	
EndProcedure

#EndRegion

#Region GLAccounts

&AtClientAtServerNoContext
Procedure AddGLAccountsToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	Object = Form.Object;

	StructureData.Insert("ProductGLAccounts",	True);
	StructureData.Insert("GLAccounts",			TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",	TabRow.GLAccountsFilled);
	StructureData.Insert("InventoryGLAccount",	TabRow.InventoryGLAccount);
	StructureData.Insert("GoodsInvoicedNotDeliveredGLAccount",	TabRow.GoodsInvoicedNotDeliveredGLAccount);
	StructureData.Insert("AdvanceInvoicing",	TabRow.AdvanceInvoicing);
	StructureData.Insert("VATInputGLAccount",	TabRow.VATInputGLAccount);
	
	If Object.VATIsDue = PredefinedValue("Enum.VATDueOnCustomsClearance.InTheVATReturn") Then 
		StructureData.Insert("VATOutputGLAccount",	TabRow.VATOutputGLAccount);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(ParametersStructure)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	Tables = New Array();
	
	If ParametersStructure.FillHeader Then
		
		Header = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Header", Object);
		GLAccountsInDocuments.CompleteCounterpartyStructureData(Header, ObjectParameters, "Header");
		
		Tables.Add(Header);
		
	EndIf;
	
	If ParametersStructure.FillInventory Then
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Inventory");
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters, "Inventory");
		
		Tables.Add(StructureData);
		
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, Tables, ParametersStructure.GetGLAccounts);
	
	If ParametersStructure.FillHeader Then
		GLAccounts = Header.GLAccounts;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryAdvanceInvoicingOnChangeAtClient(TabRow)
	
	StructureData = New Structure;
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("Object", Object);
	
	If UseDefaultTypeOfAccounting Then
		AddGLAccountsToStructure(ThisObject, "Inventory", StructureData, TabRow);
	EndIf;
	
	StructureData.Insert("Products", TabRow.Products);

	InventoryAdvanceInvoicingOnChangeAtServer(StructureData);
	FillPropertyValues(TabRow, StructureData);
	
EndProcedure

&AtServer
Procedure InventoryAdvanceInvoicingOnChangeAtServer(StructureData)
	
	If UseDefaultTypeOfAccounting Then
		
		ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
		
		StructureData.Insert("ObjectParameters", ObjectParameters);
		
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

#Region DataImportFromExternalSources

&AtClient
Procedure DataImportFromExternalSources(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"CustomsDeclaration.Inventory");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import products from file'; ru = 'Загрузка запасов из файла';pl = 'Importuj produkty z pliku';es_ES = 'Importar los productos del archivo';es_CO = 'Importar los productos del archivo';tr = 'Ürünleri dosyadan içe aktar';it = 'Importazione articoli da file';de = 'Produkte aus Datei importieren'"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object);
		
EndProcedure

#EndRegion

#Region Printing

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

#Region Properties

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

#EndRegion

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion