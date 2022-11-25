#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Counterparty",
		DriveServer.GetCompany(Company)
	);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Procedure receives the planning period data.
//
Function GetPlanningPeriodData(PlanningPeriod)
	
	StructureData = New Structure();
	
	StructureData.Insert("Periodicity", PlanningPeriod.Periodicity);
	StructureData.Insert("StartDate", PlanningPeriod.StartDate);
	StructureData.Insert("EndDate", PlanningPeriod.EndDate);
	
	Return StructureData;
	
EndFunction

&AtClient
// Procedure adjusts the planning date to the planning period.
//
Procedure AlignPlanningDateByPlanningPeriod(PlanningDate)
	
	If Periodicity = PredefinedValue("Enum.Periodicity.Day") Then
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Week") Then
		
		PlanningDate = BegOfWeek(PlanningDate);
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.TenDays") Then
		
		If Day(PlanningDate) < 11 Then
			
			PlanningDate = Date(Year(PlanningDate), Month(PlanningDate), 1);
			
		ElsIf Day(PlanningDate) < 21 Then	
			
			PlanningDate = Date(Year(PlanningDate), Month(PlanningDate), 11);
			
		Else
			
			PlanningDate = Date(Year(PlanningDate), Month(PlanningDate), 21);
			
		EndIf;
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Month") Then
		
		PlanningDate = BegOfMonth(PlanningDate);
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Quarter") Then
		
		PlanningDate = BegOfQuarter(PlanningDate);
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.HalfYear") Then
		
		MonthOfStartDate = Month(PlanningDate);
		
		PlanningDate = BegOfYear(PlanningDate);
		
		If MonthOfStartDate > 6 Then
			
			PlanningDate = AddMonth(PlanningDate, 6);
			
		EndIf;
		
	ElsIf Periodicity = PredefinedValue("Enum.Periodicity.Year") Then
		
		PlanningDate = BegOfYear(PlanningDate);
		
	Else
		
		PlanningDate = '00010101';
		
	EndIf;
	
	If StartDate <> '00010101'
		AND (PlanningDate < StartDate
		OR PlanningDate > EndDate) Then
		
		PlanningDate = StartDate;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
// Receives the data set from server for procedure AccountOnChange .
//
Function IncomeAndExpenseTypeIsOther(IncomeAndExpenseItem)
	
	IncomeAndExpenseType = IncomeAndExpenseItem.IncomeAndExpenseType;
	
	If IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.OtherIncome
		Or IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.OtherExpenses Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

&AtServer
Procedure FillAddedColumns(ParametersStructure)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	If ParametersStructure.FillIncomings Then
		
		Incomings = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Incomings");
		GLAccountsInDocuments.CompleteStructureData(Incomings, ObjectParameters, "Incomings");
		
		StructureArray.Add(Incomings);
		
	EndIf;
	
	If ParametersStructure.FillExpenses Then
		
		Expenses = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "Expenses");
		GLAccountsInDocuments.CompleteStructureData(Expenses, ObjectParameters, "Expenses");
		
		StructureArray.Add(Expenses);
		
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
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
	
	StructureData = GetPlanningPeriodData(Object.PlanningPeriod);
	Periodicity = StructureData.Periodicity;
	StartDate = StructureData.StartDate;
	EndDate = StructureData.EndDate; 
	
	User = Users.CurrentUser();
	
	SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
	MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillIncomings", True);
	ParametersStructure.Insert("FillExpenses", True);
	
	FillAddedColumns(ParametersStructure);
	
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
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts", False);
	ParametersStructure.Insert("FillIncomings", True);
	ParametersStructure.Insert("FillExpenses", True);
	
	FillAddedColumns(ParametersStructure);
	
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

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	False);
	ParametersStructure.Insert("FillIncomings",	True);
	ParametersStructure.Insert("FillExpenses",	True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	EndIf;
	
EndProcedure

#Region ProcedureFormEventHandlersHeaderAttributes

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
	Counterparty = StructureData.Counterparty;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("GetGLAccounts",	True);
	ParametersStructure.Insert("FillIncomings",	True);
	ParametersStructure.Insert("FillExpenses",	True);
	
	FillAddedColumns(ParametersStructure);
	
EndProcedure

&AtClient
// Procedure - handler of event OnChange of input field PlanningPeriod.
//
Procedure PlanningPeriodOnChange(Item)
	
	StructureData = GetPlanningPeriodData(Object.PlanningPeriod);	
	Periodicity = StructureData.Periodicity;
	StartDate = StructureData.StartDate;
	EndDate = StructureData.EndDate;
	
	For Each TabularSectionRow In Object.DirectCost Do
		AlignPlanningDateByPlanningPeriod(TabularSectionRow.PlanningDate);
	EndDo;	
	
	For Each TabularSectionRow In Object.IndirectExpenses Do
		AlignPlanningDateByPlanningPeriod(TabularSectionRow.PlanningDate);
	EndDo;	
	
	For Each TabularSectionRow In Object.Incomings Do
		AlignPlanningDateByPlanningPeriod(TabularSectionRow.PlanningDate);
	EndDo;	
	
	For Each TabularSectionRow In Object.Expenses Do
		AlignPlanningDateByPlanningPeriod(TabularSectionRow.PlanningDate);
	EndDo;	
	
	For Each TabularSectionRow In Object.Receipts Do
		AlignPlanningDateByPlanningPeriod(TabularSectionRow.PlanningDate);
	EndDo;	
	
	For Each TabularSectionRow In Object.Disposal Do
		AlignPlanningDateByPlanningPeriod(TabularSectionRow.PlanningDate);
	EndDo;	
	
	For Each TabularSectionRow In Object.Operations Do
		AlignPlanningDateByPlanningPeriod(TabularSectionRow.PlanningDate);
	EndDo;	
	
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
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlersOfTabularSectionDirectExpenses

&AtClient
// Procedure - handler of event OnChange of input field IncomePlanningDateOnChange.
// 
Procedure DirectCostPlanningDateOnChange(Item)
	
	If ValueIsFilled(Object.PlanningPeriod)
	   AND Items.DirectCost.CurrentData.PlanningDate <> '00010101' Then
		
		AlignPlanningDateByPlanningPeriod(Items.DirectCost.CurrentData.PlanningDate);	
		
	EndIf;	

EndProcedure

#EndRegion

#Region ProcedureFormEventHandlersOfTabularSectionIndirectExpenses

&AtClient
// Procedure - handler of event OnChange of input field IncomePlanningDateOnChange.
// 
Procedure IndirectExpensesPlanningDateOnChange(Item)
	
	If ValueIsFilled(Object.PlanningPeriod)
	   AND Items.IndirectExpenses.CurrentData.PlanningDate <> '00010101' Then
		
		AlignPlanningDateByPlanningPeriod(Items.IndirectExpenses.CurrentData.PlanningDate);	
		
	EndIf;	

EndProcedure

#EndRegion

#Region ProcedureFormEventHandlersOfIncomeTabularSection

&AtClient
// Procedure - handler of event OnChange of input field IncomePlanningDateOnChange.
// 
Procedure IncomePlanningDateOnChange(Item)
	
	If ValueIsFilled(Object.PlanningPeriod)
	   AND Items.Incomings.CurrentData.PlanningDate <> '00010101' Then
		
		AlignPlanningDateByPlanningPeriod(Items.Incomings.CurrentData.PlanningDate);	
		
	EndIf;	

EndProcedure

&AtClient
// Procedure - handler of event OnChange of input field AccountOnChange.
// 
Procedure IncomeAccountOnChange(Item)
	
	TabularSectionRow = Items.Incomings.CurrentData;
	
	IsOther = IncomeAndExpenseTypeIsOther(TabularSectionRow.IncomeItem);
	
	If IsOther Then
		TabularSectionRow.StructuralUnit = Undefined;
	ElsIf Not ValueIsFilled(TabularSectionRow.StructuralUnit) Then
		TabularSectionRow.StructuralUnit = MainDepartment;
	EndIf;
	
	GLAccountOnChange(TabularSectionRow, "Incomings");
	
EndProcedure

&AtClient
Procedure IncomingsIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Incomings", StandardProcessing);
	
EndProcedure

&AtClient
Procedure IncomingsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "IncomingsIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Incomings");
	EndIf;
	
EndProcedure

&AtClient
Procedure IncomingsOnActivateCell(Item)
	
	CurrentData = Items.Incomings.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Incomings.CurrentItem;
		If TableCurrentColumn.Name = "IncomingsIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			SelectedRow = Items.Incomings.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Incomings");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure IncomingsOnStartEdit(Item, NewRow, Clone)
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	
EndProcedure

&AtClient
Procedure IncomingsOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlersOfCostsTabularSection

&AtClient
// Procedure - handler of event OnChange of input field PlanningDate.
// 
Procedure ExpensesPlanningDateOnChange(Item)
	
	If ValueIsFilled(Object.PlanningPeriod)
	   AND Items.Expenses.CurrentData.PlanningDate <> '00010101' Then
		
		AlignPlanningDateByPlanningPeriod(Items.Expenses.CurrentData.PlanningDate);	
		
	EndIf;	

EndProcedure

&AtClient
// Procedure - handler of event OnChange of input field ExpensesAccountOnChange.
//
Procedure ExpensesGLAccountOnChange(Item)
	
	TabularSectionRow = Items.Expenses.CurrentData;
	
	IsOther = IncomeAndExpenseTypeIsOther(TabularSectionRow.ExpenseItem);
	
	If IsOther Then
		TabularSectionRow.StructuralUnit = Undefined;
	ElsIf Not ValueIsFilled(TabularSectionRow.StructuralUnit) Then
		TabularSectionRow.StructuralUnit = MainDepartment;
	EndIf;
	
	GLAccountOnChange(TabularSectionRow, "Expenses");
	
EndProcedure

&AtClient
Procedure ExpensesIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Expenses", StandardProcessing);
	
EndProcedure

&AtClient
Procedure ExpensesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "ExpensesIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Expenses");
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesOnActivateCell(Item)
	
	CurrentData = Items.Expenses.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Expenses.CurrentItem;
		If TableCurrentColumn.Name = "ExpensesIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			SelectedRow = Items.Expenses.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Expenses");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpensesOnStartEdit(Item, NewRow, Clone)
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Clone);
	
EndProcedure

&AtClient
Procedure ExpensesOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlersOfReceiptTabularSection

&AtClient
// Procedure - handler of event OnChange of input field IncomePlanningDateOnChange.
// 
Procedure ReceiptsPlanningDateOnChange(Item)
	
	If ValueIsFilled(Object.PlanningPeriod)
	   AND Items.Receipts.CurrentData.PlanningDate <> '00010101' Then
		
		AlignPlanningDateByPlanningPeriod(Items.Receipts.CurrentData.PlanningDate);	
		
	EndIf;	

EndProcedure

#EndRegion

#Region ProcedureFormEventHandlersOfExpenseTabularSection

&AtClient
// Procedure - handler of event OnChange of input field PlanningDate.
// 
Procedure OutflowsPlanningDateOnChange(Item)
	
	If ValueIsFilled(Object.PlanningPeriod)
	   AND Items.Disposal.CurrentData.PlanningDate <> '00010101' Then
	   
		AlignPlanningDateByPlanningPeriod(Items.Disposal.CurrentData.PlanningDate);	
		
	EndIf;	

EndProcedure

#EndRegion

#Region ProcedureFormEventHandlersOfOperationsTabularSection

&AtClient
// Procedure - handler of event OnChange of input field PlanningDate.
//
Procedure OperationsPlanningDateOnChange(Item)
	
	If ValueIsFilled(Object.PlanningPeriod)
	   AND Items.Operations.CurrentData.PlanningDate <> '00010101' Then
		
		AlignPlanningDateByPlanningPeriod(Items.Operations.CurrentData.PlanningDate);	
		
	EndIf;	

EndProcedure

#EndRegion

#EndRegion

#Region Internal

&AtClient
Procedure GLAccountOnChange(TabularSectionRow, TabName)
	
	StructureData = New Structure("
	|TabName,
	|Object,
	|Account,
	|IncomeAndExpenseItems,
	|IncomeAndExpenseItemsFilled,
	|IncomeItem,
	|ExpenseItem");
	
	StructureData.Object = Object;
	StructureData.TabName = TabName;
	FillPropertyValues(StructureData, TabularSectionRow);
	
	GLAccountsInDocumentsServerCall.CheckItemRegistration(StructureData);
	FillPropertyValues(TabularSectionRow, StructureData);
	
EndProcedure

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