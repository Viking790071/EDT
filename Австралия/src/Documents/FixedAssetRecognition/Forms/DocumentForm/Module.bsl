#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

&AtServerNoContext
// Calculates the cost of fixed asset
//
Function GetCostFixedAsset(StructureData)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	CASE
	|		WHEN InventoryBalance.QuantityBalance = 0
	|			THEN 0
	|		ELSE InventoryBalance.AmountBalance / InventoryBalance.QuantityBalance
	|	END AS Cost,
	|	InventoryBalance.QuantityBalance AS QuantityBalance
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&Period,
	|			Products = &Products
	|				AND Characteristic = &Characteristic
	|				AND Ownership IN
	|					(SELECT
	|						InventoryOwnership.Ref AS Ownership
	|					FROM
	|						Catalog.InventoryOwnership AS InventoryOwnership
	|					WHERE
	|						InventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.OwnInventory))) AS InventoryBalance";
	
	Query.SetParameter("Period",		 StructureData.Period);
	Query.SetParameter("Products",		 StructureData.Products);
	Query.SetParameter("Characteristic", StructureData.Characteristic);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return 0;
	EndIf;
	
	Selection = QueryResult.Select(QueryResultIteration.ByGroups);
	Selection.Next();
	
	If StructureData.Quantity > Selection.QuantityBalance Then
		Return 0;
	Else
		Return Selection.Cost * StructureData.Quantity;
	EndIf;
	
EndFunction

&AtServer
// It receives data set from server for the ContractOnChange procedure.
//
Function GetCompanyDataOnChange(Company, DocumentCurrency)
	
	FillAddedColumns(True);
	
	StructureData = New Structure();
	StructureData.Insert("Counterparty", DriveServer.GetCompany(Company));
	
	If Company = Catalogs.Companies.EmptyRef() Then
		DocumentCurrency = Catalogs.Currencies.EmptyRef()
	Else
		DocumentCurrency = DriveServer.GetPresentationCurrency(Company);
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure StructuralUnitOnChangeAtServer()
	
	FillAddedColumns(True);
	
EndProcedure

&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function GetDataProductsOnChange(StructureData)
	
	Object = StructureData.Object;
	StructureData.Insert("Object", Object);
	StructureData.Insert("Products", Object.Products);
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("InventoryGLAccount", Object.InventoryGLAccount);
		StructureData.Insert("GLAccounts", "");
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServer
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function GetDataFixedAsset(FixedAsset)
	
	StructureData = New Structure();
	StructureData.Insert("MethodOfDepreciationProportionallyProductsAmount", 
		FixedAsset.DepreciationMethod = Enums.FixedAssetDepreciationMethods.ProportionallyToProductsVolume);
		
	FillAddedColumns();
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	If UseDefaultTypeOfAccounting Then
		
		ProductInHeader = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "InitialCost");
		GLAccountsInDocuments.CompleteStructureData(ProductInHeader, ObjectParameters, "InitialCost");
		StructureArray.Add(ProductInHeader);
		
	EndIf;
	
	FixedAssets = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "FixedAssets", Object);
	GLAccountsInDocuments.CompleteStructureData(FixedAssets, ObjectParameters, "FixedAssets");
	StructureArray.Add(FixedAssets);
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, GetGLAccounts);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInitialCost = ProductInHeader.GLAccounts;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function IsIncomeAndExpenseGLA(Account)
	Return GLAccountsInDocumentsServerCall.IsIncomeAndExpenseGLA(Account);
EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	EndIf;
	
EndProcedure

&AtServer
// Procedure - event handler "OnCreateAtServer".
// The procedure implements
// - form attribute initialization,
// - setting of the form functional options parameters.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	If Object.Company = Catalogs.Companies.EmptyRef() Then
		DocumentCurrency = Catalogs.Currencies.EmptyRef()
	Else 
		DocumentCurrency = DriveServer.GetPresentationCurrency(Object.Company);
	EndIf;
	
	User = Users.CurrentUser();
	
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	FillAddedColumns();
	
	IncomeAndExpenseItemsInDocuments.SetRegistrationAttributesVisibility(ThisObject, "FixedAssetsRegisterExpense");
	
	Items.GLAccountsInitialCost.Visible = UseDefaultTypeOfAccounting;
	
	DefaultExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DepreciationCharge");
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
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
	
	FillAddedColumns();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
// Procedure - event handler AfterWriting.
//
Procedure AfterWrite(WriteParameters)
	
	Notify("FixedAssetsStatesUpdate");
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillAddedColumns();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
Procedure QuantityOnChange(Item)
	
	If Object.Quantity = 0 Then
		Object.Amount = 0;
	Else
		StructureData = New Structure("Products, Characteristic", Object.Products, Object.Characteristic);
		StructureData.Insert("Period",				Object.Date);
		StructureData.Insert("Products",	Object.Products);
		StructureData.Insert("Characteristic", 		Object.Characteristic);
		StructureData.Insert("Quantity",			Object.Quantity);
		
		Object.Amount = GetCostFixedAsset(StructureData);
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company, DocumentCurrency);
	Counterparty = StructureData.Counterparty;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure ProductsOnChange(Item)
	
	StructureData = New Structure;
	StructureData.Insert("Object", Object);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	Object.MeasurementUnit = StructureData.MeasurementUnit;
	
	If UseDefaultTypeOfAccounting Then
		Object.InventoryGLAccount = StructureData.InventoryGLAccount;
		GLAccountsInitialCost = StructureData.GLAccounts;
	EndIf;
	
EndProcedure

&AtClient
Procedure StructuralUnitOnChange(Item)
	StructuralUnitOnChangeAtServer();
EndProcedure

&AtClient
Procedure GLAccountsInitialCostClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, Object, "InitialCost");
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#Region TabularSectionAttributeEventHandlers

&AtClient
// Procedure - OnStartEdit event handler of the FixedAssets tabular section.
//
Procedure FixedAssetsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
 
		TabularSectionRow = Items.FixedAssets.CurrentData;
		TabularSectionRow.StructuralUnit = MainDepartment;
		
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of
// input field WorksProductsVolumeForDepreciationCalculation in
// string of tabular section FixedAssets.
//
Procedure FixedAssetsVolumeProductsWorksForDepreciationCalculationOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If Not StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		ShowMessageBox(Undefined,NStr("en = '""Product (work) volume for calculating depreciation"" cannot be filled in for the specified depreciation method.'; ru = '""Объем продукции (работ) для исчисления амортизации"" не может быть заполнен для указанного способа начисления амортизации!';pl = 'Dla określonej metody amortyzacji nie można wypełnić pola ""Trwałość użyteczna do metody amortyzacji"".';es_ES = '""Volumen de productos (trabajos) para calcular la depreciación"" no puede rellenarse para el método de depreciación especificado.';es_CO = '""Volumen de productos (trabajos) para calcular la depreciación"" no puede rellenarse para el método de depreciación especificado.';tr = '""Amortisman hesaplamasında kullanılan ürün (iş) hacmi"", belirtilen amortisman tahakkuku yöntemi için doldurulmamıştır.';it = '""Il volume del prodotto (lavoro) per il calcolo degli ammortamenti"" non può essere compilato per il metodo di ammortamento specificato.';de = '""Produkt (Arbeit) Volumen zur Berechnung der Abschreibung"" kann für die angegebene Abschreibungsmethode nicht ausgefüllt werden.'"));
		TabularSectionRow.AmountOfProductsServicesForDepreciationCalculation = 0;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of
// input field UsagePeriodForDepreciationCalculation in string
// of tabular section FixedAssets.
//
Procedure FixedAssetsUsagePeriodForDepreciationCalculationOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		ShowMessageBox(Undefined,NStr("en = 'Cannot fill in ""Useful life for calculating depreciation"" for the specified method of depreciation.'; ru = '""Срок использования для вычисления амортизации"" не может быть заполнен для указанного способа начисления амортизации!';pl = 'Dla określonej metody amortyzacji nie można wypełnić pola ""Liczba miesięcy amortyzacji do obliczenia"".';es_ES = 'No se puede rellenar la ""Vida útil para calcular la depreciación"" para el método especificado de la depreciación.';es_CO = 'No se puede rellenar la ""Vida útil para calcular la depreciación"" para el método especificado de la depreciación.';tr = 'Belirtilen amortisman yöntemi için ""Amortismanın hesaplanması için yararlı ömür"" doldurulamaz.';it = 'Il ""Vita utile per il calcolo dell''ammortamento"" non può essere compilato per il metodo di calcolo dell''ammortamento specificato!';de = 'Für die angegebene Abschreibungsmethode kann die ""Nutzungsdauer für die Berechnung der Abschreibungen"" nicht angegeben werden.'"));
		TabularSectionRow.UsagePeriodForDepreciationCalculation = 0;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of
// input field FixedAsset in string of tabular section FixedAssets.
//
Procedure FixedAssetsFixedAssetOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	TabularSectionRow.ExpenseItem = DefaultExpenseItem;
	If UseDefaultTypeOfAccounting Then
		TabularSectionRow.RegisterExpense = IsIncomeAndExpenseGLA(TabularSectionRow.GLExpenseAccount);
	Else
		TabularSectionRow.RegisterExpense = True;
	EndIf;
	
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		TabularSectionRow.UsagePeriodForDepreciationCalculation = 0;
	Else
		TabularSectionRow.AmountOfProductsServicesForDepreciationCalculation = 0;
	EndIf;
	
	FillAddedColumns();
	
EndProcedure

&AtClient
Procedure FixedAssetsIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "FixedAssets", StandardProcessing);
	
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
Procedure FixedAssetsGLExpenseAccountOnChange(Item)
	
	CurData = Items.FixedAssets.CurrentData;
	If CurData <> Undefined Then
		
		StructureData = New Structure("
		|TabName,
		|Object,
		|GLExpenseAccount,
		|IncomeAndExpenseItems,
		|IncomeAndExpenseItemsFilled,
		|ExpenseItem,
		|RegisterExpense,
		|Manual");
		StructureData.Object = Object;
		StructureData.TabName = "FixedAssets";
		FillPropertyValues(StructureData, CurData);
		
		GLAccountsInDocumentsServerCall.CheckItemRegistration(StructureData);
		FillPropertyValues(CurData, StructureData);
		
		FillAddedColumns();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FixedAssetsRegisterExpenseOnChange(Item)
	
	CurrentData = Items.FixedAssets.CurrentData;
	
	If CurrentData <> Undefined And Not CurrentData.RegisterExpense Then
		CurrentData.ExpenseItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
		FillAddedColumns();
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

#EndRegion

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion