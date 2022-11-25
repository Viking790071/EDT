#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region ServiceHandlers

&AtClient
// Procedure changes the current row of the Employees tabular section
//
Procedure ChangeCurrentEmployee()
	
	Items.Employees.CurrentRow = CurrentEmployee;
	
EndProcedure

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction

&AtServer
// Procedure fills the selection list of the "Current employee" control field
//
Procedure FillCurrentEmployeesChoiceList()
	
	Items.CurrentEmployeeEarningsDeductions.ChoiceList.Clear();
	Items.CurrentEmployeeTaxes.ChoiceList.Clear();
	For Each RowEmployee In Object.Employees Do
		
		RowPresentation = String(RowEmployee.Employee) + ", " + NStr("en = 'employee ID'; ru = 'Таб. номер';pl = 'Identyfikator pracownika';es_ES = 'identificación de empleado';es_CO = 'identificación de empleado';tr = 'Çalışan Kimlik numarası';it = 'ID dipendente';de = 'Mitarbeiter-ID'") + ": " + String(RowEmployee.Employee.Code);
		Items.CurrentEmployeeEarningsDeductions.ChoiceList.Add(RowEmployee.GetID(), RowPresentation);
		Items.CurrentEmployeeTaxes.ChoiceList.Add(RowEmployee.GetID(), RowPresentation);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	EarningsDeductions = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "EarningsDeductions");
	GLAccountsInDocuments.CompleteStructureData(EarningsDeductions, ObjectParameters, "EarningsDeductions");
	
	StructureArray.Add(EarningsDeductions);
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, GetGLAccounts);
	
EndProcedure

&AtServerNoContext
Function ExpenseTypeOfEarningAndDeductionType(EarningAndDeductionType)
	Return Common.ObjectAttributeValue(EarningAndDeductionType, "Type") = Enums.EarningAndDeductionTypes.Earning;
EndFunction

#EndRegion

#Region FormEventsHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(Object,
	,
	Parameters.CopyingValue,
	Parameters.Basis,
	PostingIsAllowed,
	Parameters.FillingValues);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	TabularSectionName = "Employees";
	CurrencyByDefault = Constants.FunctionalCurrency.Get();
	
	If Not Constants.UseSecondaryEmployment.Get() Then
		If Items.Find("EmployeesEmployeeCode") <> Undefined Then
			Items.EmployeesEmployeeCode.Visible = False;
		EndIf;
	EndIf;
	
	User = Users.CurrentUser();
	
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
	
	TaxAccounting = GetFunctionalOption("UsePersonalIncomeTaxCalculation");
	CommonClientServer.SetFormItemProperty(Items, "CurrentEmployeeTaxes", "Visible", TaxAccounting);
	If Not TaxAccounting Then
		
		Items.Employees.ExtendedTooltip.Title = 
			NStr("en = 'Earnings and deductions are specified on the corresponding page for each employee individually.'; ru = 'Начисления и удержания указываются на соответствующей вкладке отдельно для каждого сотрудника.';pl = 'Zarobki i potrącenia są określony na odpowiedniej stronie dla każdego pracownika z osobna.';es_ES = 'Ingresos y deducciones están especificados en la página correspondiente para cada empleado de forma individual.';es_CO = 'Ingresos y deducciones están especificados en la página correspondiente para cada empleado de forma individual.';tr = 'Kazanç ve kesintiler, her bir çalışan için tek tek ilgili sayfada belirtilir.';it = 'Compensi e trattenute sono specificati nella pagina corrispondente per ogni dipendente in modo individuale.';de = 'Die Bezüge und Abzüge werden auf der entsprechenden Seite für jeden Mitarbeiter einzeln angegeben.'");
			
	EndIf;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	DefaultExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("PayrollExpenses");
	DefaultIncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("PayrollIncome");
	FillAddedColumns();
	
	IncomeAndExpenseItemsInDocuments.SetConditionalAppearance(ThisObject, "EarningsDeductions");
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
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
	FillAddedColumns();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillAddedColumns();
	
EndProcedure

#EndRegion

#Region HeaderAttributesHandlers

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
	StructureData = GetCompanyDataOnChange(Object.Company);
	ParentCompany = StructureData.Company;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
// Procedure - event handler OnCurrentPageChange of field PagesMain
//
Procedure PagesMainOnCurrentPageChange(Item, CurrentPage)
	
	If CurrentPage = Items.PageEarningsDeductions
		OR CurrentPage = Items.PageTaxes Then
		
		FillCurrentEmployeesChoiceList();
		
		DataCurrentRows = Items.Employees.CurrentData;
		
		If DataCurrentRows <> Undefined Then
			
			CurrentEmployee = DataCurrentRows.GetID();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of field CurrentEmployeeDeductionEarnings
//
Procedure CurrentEmployeeEarningsDeductionsOnChange(Item)
	
	ChangeCurrentEmployee();
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of field CurrentEmployeeTaxes
//
Procedure CurrentEmployeeTaxesOnChange(Item)
	
	ChangeCurrentEmployee();
	
EndProcedure

#EndRegion

#Region TabularSectionsHandlers

&AtClient
// Procedure - event handler OnActivate of the Employees tabular section row.
//
Procedure EmployeesOnActivateRow(Item)
		
	DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "EarningsDeductions");
	DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "IncomeTaxes");
	
EndProcedure

&AtClient
// Procedure - handler of event OnStartEdit of tabular section Employees.
//
Procedure EmployeesOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		DriveClient.AddConnectionKeyToTabularSectionLine(ThisForm);
		DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "EarningsDeductions");
		DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "IncomeTaxes");
		
		TabularSectionRow = Items.Employees.CurrentData;
		If Not ValueIsFilled(TabularSectionRow.StructuralUnit) Then
			
			TabularSectionRow.StructuralUnit = MainDepartment;
			
		EndIf;
		
	EndIf;

EndProcedure

&AtClient
// Procedure - event handler BeforeDelete of tabular section Employees.
//
Procedure EmployeesBeforeDelete(Item, Cancel)

	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "EarningsDeductions");
    DriveClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "IncomeTaxes");

EndProcedure

&AtClient
// Procedure - event handler OnChange of the Employee of the Employees tabular section.
//
Procedure EmployeesEmployeeOnChange(Item)
	
	Items.Employees.CurrentData.OccupiedRates = 1;
	
EndProcedure

&AtClient
// Procedure - event handler OnStartEdit of tabular section DeductionEarnings.
//
Procedure EarningsDeductionsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		DriveClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
		TabularSectionRow = Items.EarningsDeductions.CurrentData;
		TabularSectionRow.Currency = CurrencyByDefault;
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);

EndProcedure

&AtClient
Procedure EarningsDeductionsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "EarningsDeductionsIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "EarningsDeductions");
	EndIf;
	
EndProcedure

&AtClient
Procedure EarningsDeductionsOnActivateCell(Item)
	
	CurrentData = Items.EarningsDeductions.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.EarningsDeductions.CurrentItem;
		If TableCurrentColumn.Name = "EarningsDeductionsIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			SelectedRow = Items.EarningsDeductions.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "EarningsDeductions");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure EarningsDeductionsOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
// Procedure - event handler BeforeAdditionStart of tabular section DeductionEarnings.
//
Procedure EarningsDeductionsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisForm, Item.Name);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange DeductionEarningKind of tabular section DeductionEarnings.
//
Procedure EarningsDeductionsEarningAndDeductionTypeOnChange(Item)
	
	CurrentData = Items.EarningsDeductions.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ExpenseTypeOfEarningAndDeductionType(CurrentData.EarningAndDeductionType) Then
		CurrentData.ExpenseItem = DefaultExpenseItem;
		CurrentData.IncomeItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
	Else
		CurrentData.IncomeItem = DefaultIncomeItem;
		CurrentData.ExpenseItem = PredefinedValue("Catalog.IncomeAndExpenseItems.EmptyRef");
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		DriveClient.PutExpensesGLAccountByDefault(ThisForm);
		EarningsDeductionsExpensesAccountOnChange(Undefined);
	Else
		FillAddedColumns();
	EndIf;
	
EndProcedure

&AtClient
Procedure EarningsDeductionsIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "EarningsDeductions", StandardProcessing);
	
EndProcedure

&AtClient
// Procedure - event handler OnStartEdit of tabular section IncomeTaxes.
//
Procedure IncomeTaxesOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		DriveClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
		TabularSectionRow = Items.IncomeTaxes.CurrentData;
		TabularSectionRow.Currency = CurrencyByDefault;
	EndIf;

EndProcedure

&AtClient
// Procedure - event handler BeforeAdditionStart of tabular section IncomeTaxes.
//
Procedure IncomeTaxesBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisForm, Item.Name);
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
EndProcedure

&AtClient
Procedure EarningsDeductionsExpensesAccountOnChange(Item)
	
	CurData = Items.EarningsDeductions.CurrentData;
	If CurData <> Undefined Then
		
		StructureData = New Structure("
		|TabName,
		|Object,
		|GLExpenseAccount,
		|EarningAndDeductionType,
		|IncomeAndExpenseItems,
		|IncomeAndExpenseItemsFilled,
		|ExpenseItem,
		|IncomeItem");
		StructureData.Object = Object;
		StructureData.TabName = "EarningsDeductions";
		FillPropertyValues(StructureData, CurData);
		
		GLAccountsInDocumentsServerCall.CheckItemRegistration(StructureData);
		FillPropertyValues(CurData, StructureData);
		
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