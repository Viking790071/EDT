#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region Private

&AtServer
// Procedure fills the exchange rates table
//
Procedure FillTableFixedAssets()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DepreciationParametersSliceLast.FixedAsset AS FixedAsset,
	|	DepreciationParametersSliceLast.StructuralUnit AS Department,
	|	DepreciationParametersSliceLast.AmountOfProductsServicesForDepreciationCalculation AS AmountOfProductsServicesForDepreciationCalculation,
	|	DepreciationParametersSliceLast.CostForDepreciationCalculation AS CostForDepreciationCalculation,
	|	DepreciationParametersSliceLast.UsagePeriodForDepreciationCalculation AS UsagePeriodForDepreciationCalculation,
	|	&DepreciationCharge AS ExpenseItem,
	|	&OtherIncome AS RevaluationItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DepreciationParametersSliceLast.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLExpenseAccount,
	|	DepreciationParametersSliceLast.BusinessLine AS BusinessLine
	|FROM
	|	InformationRegister.FixedAssetParameters.SliceLast(&DocumentDate, Company = &Company) AS DepreciationParametersSliceLast";
	
	Query.SetParameter("DocumentDate", DocumentDate);
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	Query.SetParameter("DepreciationCharge", Catalogs.DefaultIncomeAndExpenseItems.GetItem("DepreciationCharge"));
	Query.SetParameter("OtherIncome", Catalogs.DefaultIncomeAndExpenseItems.GetItem("OtherIncome"));
	
	QueryResultTable = Query.Execute().Unload();
	TableFixedAssets.Load(QueryResultTable);
	
EndProcedure

&AtServerNoContext
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("ParentCompany", DriveServer.GetCompany(Company));
	
	If Company = Catalogs.Companies.EmptyRef() Then
		DocumentCurrency = Catalogs.Currencies.EmptyRef()
	Else
		DocumentCurrency = DriveServer.GetPresentationCurrency(Company);
	EndIf;
	
	StructureData.Insert("DocumentCurrency", DocumentCurrency);
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure CompanyOnChangeAtServer()
	
	StructureData = GetCompanyDataOnChange(Object.Company);
	ParentCompany = StructureData.ParentCompany;
	DocumentCurrency = StructureData.DocumentCurrency;
	
	FillTableFixedAssets();
	
EndProcedure

&AtServer
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function GetDataFixedAsset(FixedAsset)
	
	StructureData = New Structure;
	StructureData.Insert("MethodOfDepreciationProportionallyProductsAmount", FixedAsset.DepreciationMethod = Enums.FixedAssetDepreciationMethods.ProportionallyToProductsVolume);
	
	FillAddedColumns();
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	FixedAssets = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "FixedAssets", Object);
	GLAccountsInDocuments.CompleteStructureData(FixedAssets, ObjectParameters, "FixedAssets");
	
	StructureArray = New Array();
	StructureArray.Add(FixedAssets);
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, GetGLAccounts);
	
EndProcedure

&AtClientAtServerNoContext
Function AccountOnChangeStructure(Object, AccountName)
	
	StructureData = New Structure("
	|TabName,
	|Object,
	|IncomeAndExpenseItems,
	|IncomeAndExpenseItemsFilled,
	|ExpenseItem,
	|RegisterExpense,
	|RevaluationItem,
	|RegisterRevaluation");
	StructureData.Object = Object;
	StructureData.TabName = "FixedAssets";
	
	StructureData.Insert(AccountName);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function IsIncomeAndExpenseGLA(Account)
	Return GLAccountsInDocumentsServerCall.IsIncomeAndExpenseGLA(Account);
EndFunction

&AtClient
Procedure Attachable_ProcessDateChange()
	
	DocumentDate = Object.Date;
	
	FillTableFixedAssets();
	
EndProcedure

#EndRegion

#Region FormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
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
	
	If ValueIsFilled(Object.Date) Then
		DocumentDate = Object.Date;
	Else
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	If Object.Company = Catalogs.Companies.EmptyRef() Then
		DocumentCurrency = Catalogs.Currencies.EmptyRef()
	Else 
		DocumentCurrency = DriveServer.GetPresentationCurrency(Object.Company);
	EndIf;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	FillTableFixedAssets();
	
	User = Users.CurrentUser();
	
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
	
	FillAddedColumns();
	
	IncomeAndExpenseItemsInDocuments.SetRegistrationAttributesVisibility(
		ThisObject, "FixedAssetsRegisterExpense, FixedAssetsRegisterRevaluation", Not UseDefaultTypeOfAccounting);
	
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
	
	FillAddedColumns();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
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
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillAddedColumns();
	
	If DocumentDate <> Object.Date Then
		DocumentDate = Object.Date;
		FillTableFixedAssets();
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject);
	
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
	
	CompanyOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersFixedAssets

&AtClient
// Procedure - event handler OnStartEdit of the FixedAssets list row.
//
Procedure FixedAssetsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		TabularSectionRow = Items.FixedAssets.CurrentData;
		TabularSectionRow.StructuralUnit = MainDepartment;
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the WorksProductsVolumeForDepreciationCalculation input field 
// in the row of the FixedAssets
// tabular section.
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
// Procedure - event handler OnChange of the UsagePeriodForDepreciationCalculation input field 
// in the row of the FixedAssets
// tabular section.
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
// Procedure - event handler OnChange of the
// FixedAsset input field in the row
// of the FixedAssets tabular section.
//
Procedure FixedAssetsFixedAssetOnChange(Item)
	
	CurrentData = Items.FixedAssets.CurrentData;
	
	FixedAssetsArray = TableFixedAssets.FindRows(New Structure("FixedAsset", CurrentData.FixedAsset));
	
	If FixedAssetsArray.Count() <> 0 Then
		
		CurrentData.UsagePeriodForDepreciationCalculation = FixedAssetsArray[0].UsagePeriodForDepreciationCalculation;
		CurrentData.AmountOfProductsServicesForDepreciationCalculation = FixedAssetsArray[0].AmountOfProductsServicesForDepreciationCalculation;
		CurrentData.CostForDepreciationCalculation = FixedAssetsArray[0].CostForDepreciationCalculation;
		CurrentData.CostForDepreciationCalculationBeforeChanging = FixedAssetsArray[0].CostForDepreciationCalculation;
		CurrentData.ExpenseItem = FixedAssetsArray[0].ExpenseItem;
		CurrentData.RevaluationItem = FixedAssetsArray[0].RevaluationItem;
		CurrentData.BusinessLine = FixedAssetsArray[0].BusinessLine;
		CurrentData.StructuralUnit = FixedAssetsArray[0].Department;
		
		If UseDefaultTypeOfAccounting Then
			CurrentData.GLExpenseAccount = FixedAssetsArray[0].GLExpenseAccount;
			CurrentData.RegisterExpense = IsIncomeAndExpenseGLA(CurrentData.GLExpenseAccount);
			CurrentData.RegisterRevaluation = IsIncomeAndExpenseGLA(CurrentData.RevaluationAccount);
		Else
			CurrentData.RegisterExpense = True;
			CurrentData.RegisterRevaluation = True;
		EndIf;
		
	Else
		CurrentData.UsagePeriodForDepreciationCalculation = 0;
		CurrentData.AmountOfProductsServicesForDepreciationCalculation = 0;
		CurrentData.CostForDepreciationCalculation = 0;
		CurrentData.CostForDepreciationCalculationBeforeChanging = 0;
	EndIf;
	
	StructureData = GetDataFixedAsset(CurrentData.FixedAsset);
	
	If StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		CurrentData.UsagePeriodForDepreciationCalculation = 0;
	Else
		CurrentData.AmountOfProductsServicesForDepreciationCalculation = 0;
	EndIf;
	
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
		
		StructureData = AccountOnChangeStructure(Object, "GLExpenseAccount");
		FillPropertyValues(StructureData, CurData);
		
		GLAccountsInDocumentsServerCall.CheckItemRegistration(StructureData);
		FillPropertyValues(CurData, StructureData);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FixedAssetsRevaluationAccountOnChange(Item)
	
	CurData = Items.FixedAssets.CurrentData;
	If CurData <> Undefined Then
		
		StructureData = AccountOnChangeStructure(Object, "RevaluationAccount");
		FillPropertyValues(StructureData, CurData);
		
		GLAccountsInDocumentsServerCall.CheckItemRegistration(StructureData);
		FillPropertyValues(CurData, StructureData);
		
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

&AtClient
Procedure FixedAssetsRegisterRevaluationOnChange(Item)
	
	CurrentData = Items.FixedAssets.CurrentData;
	
	If CurrentData <> Undefined And Not CurrentData.RegisterRevaluation Then
		CurrentData.RevaluationItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
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

#Region Initialize

ThisIsNewRow = False;

#EndRegion
