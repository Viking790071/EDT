
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("Parent", Parent);
	Object.EmploymentContractType = Enums.EmploymentContractTypes.FullTime;
	
	FillVariant = 1;
	EmploymentContractOccupiedRates = 1;
	
	SettlementsHumanResourcesGLAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollPayable");
	AdvanceHoldersGLAccount				= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHolders");
	OverrunGLAccount					= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AdvanceHoldersPayable");
	
	CompaniesUsed = GetFunctionalOption("UseSeveralCompanies");
	If CompaniesUsed Then
		
		AccountingByCompany = Constants.AccountingBySubsidiaryCompany.Get();
		If AccountingByCompany Then
			
			EmploymentContractCompany = Constants.ParentCompany.Get();
			CommonClientServer.SetFormItemProperty(Items, "EmploymentContractCompany", "Enabled", False);
			
		EndIf;
		
	Else
		EmploymentContractCompany = DriveReUse.GetUserDefaultCompany();		
		If Not ValueIsFilled(EmploymentContractCompany) Then
			EmploymentContractCompany = Catalogs.Companies.MainCompany;
		EndIf;
		
		CommonClientServer.SetFormItemProperty(Items, "EmploymentContractCompany", "Enabled", False);
		
	EndIf;
	
	DepartmentsAreUsed = GetFunctionalOption("UseSeveralDepartments");
	If Not DepartmentsAreUsed Then
		
		EmploymentContractStructuralUnit = Catalogs.BusinessUnits.MainDepartment;
		
	EndIf;
	
	EmploymentContractCurrency = DriveReUse.GetFunctionalCurrency();
	UsedCurrencies = GetFunctionalOption("ForeignExchangeAccounting");
	CommonClientServer.SetFormItemProperty(Items, "EmploymentContractCurrency", "Visible", UsedCurrencies);
	
	UsedStaffSchedule = GetFunctionalOption("UseHeadcountBudget");
	
	CommonClientServer.SetFormItemProperty(Items, "EmploymentContractOccupiedRates", "Visible", UsedStaffSchedule);
	CommonClientServer.SetFormItemProperty(Items, "EmploymentContractAddRates", "Visible", UsedStaffSchedule);
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	DefaultExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("PayrollExpenses");
	DefaultIncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("PayrollIncome");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Set the current table of transitions
	Scenario1GoToTable();
	
	// Position at the assistant's first step
	Iterator = 1;
	SetGoToNumber(Iterator);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	WarningText = NStr("en = 'Close wizard?'; ru = '?????????????? ?????????????????';pl = 'Zamkn???? kreator?';es_ES = '??Cerrar el asistente?';es_CO = '??Cerrar el asistente?';tr = 'Sihirbaz?? kapat?';it = 'Chiudere l''assistente guidato?';de = 'Den Assistenten schlie??en?'");
	CommonClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, Exit, WarningText, "ForceCloseForm");
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FillVariantOnChange(Item)
	
	Items.PagesFL.CurrentPage = ?(FillVariant = 1, Items.NewFL, Items.CurrentFL);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersEarningsDeductions

&AtClient
Procedure EarningsDeductionsEarningAndDeductionTypeOnChange(Item)
	
	CurrentData = Items.EarningsDeductions.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If IsExpenseTypeOfEarningAndDeductionType(CurrentData.EarningAndDeductionType) Then
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

&AtClient
Procedure EarningsDeductionsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "EarningsDeductionsIncomeAndExpenseItems" Then
		StandardProcessing = False;
		
		CurrentData = Items.EarningsDeductions.CurrentData;

		Structure = New Structure;
		Structure.Insert("ExpenseItem", CurrentData.ExpenseItem);
		Structure.Insert("IncomeItem", CurrentData.IncomeItem);
		Structure.Insert("EarningAndDeductionType", CurrentData.EarningAndDeductionType);
		Structure.Insert("GLExpenseAccount", CurrentData.GLExpenseAccount);
		Structure.Insert("ShamObject", GenerateShamObject());
		
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisForm, Structure, "EarningsDeductions");
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnStartEdit of tabular section DeductionEarnings.
//
Procedure EarningsDeductionsOnStartEdit(Item, NewRow, Copy)
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);

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

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CommandNext(Command)
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure CommandBack(Command)
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure CommandDone(Command)
	
	ForceCloseForm = True;
	NotifyChoice(True);
	
	PageWritten_OnGoingNext();
	
EndProcedure

&AtClient
Procedure CommandCancel(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region SuppliedPart

&AtClient
Procedure ChangeGoToNumber(IteratorLocally)
	
	ClearMessages();
	
	Iterator = IteratorLocally;
	If Iterator > 0 Then
		
		If GoToNumber = 1 And Not UseDefaultTypeOfAccounting Then
			
			// Ignore GL accounts, skip one page
			Iterator = Iterator + 1;
			
		EndIf;
		
		If GoToNumber = 2 Then
			
			If Not AssociateWithIndividual Then 
				
				// Ignore individual, skip one page
				Iterator = Iterator + 1;
				
			EndIf;
			
			If Not AssociateWithIndividual AND Not AcceptForEmploymentContract Then
				
				// Ignore employment, skip two more pages.
				Iterator = Iterator + 2;
				
			EndIf;
			
		EndIf;
		
		If GoToNumber = 3 Then
			
			If Not AcceptForEmploymentContract Then
				
				// Ignore employment, skip two pages
				Iterator = Iterator + 2;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Iterator < 0 Then
		
		If GoToNumber = 4 Then
			
			If Not AssociateWithIndividual Then
				
				// Ignore individual, skip one page
				Iterator = Iterator - 1;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	SetGoToNumber(GoToNumber + Iterator);
	
EndProcedure

&AtClient
Procedure SetGoToNumber(Val Value)
	
	IsGoNext = (Value > GoToNumber);
	
	GoToNumber = Value;
	
	If GoToNumber < 0 Then
		
		GoToNumber = 0;
		
	EndIf;
	
	GoToNumberOnChange(IsGoNext);
	
EndProcedure

&AtClient
Procedure GoToNumberOnChange(Val IsGoNext)
	
	// Executing the step change event handlers
	ExecuteGoToEventHandlers(IsGoNext);
	
	// Setting page visible
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page for displaying is not defined.'; ru = '???? ???????????????????? ???????????????? ?????? ??????????????????????.';pl = 'Nie okre??lono strony do wy??wietlenia.';es_ES = 'P??gina para visualizar no se ha definido.';es_CO = 'P??gina para visualizar no se ha definido.';tr = 'G??sterilecek sayfa tan??mlanmad??.';it = 'La pagina per la visualizzazione non ?? stata definita.';de = 'Die Seite f??r die Anzeige ist nicht definiert.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.MainPanel.CurrentPage  = Items[GoToRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[GoToRowCurrent.NavigationPageName];
	
	If Not IsBlankString(GoToRowCurrent.DecorationPageName) Then
		
		Items.DecorationPanel.CurrentPage = Items[GoToRowCurrent.DecorationPageName];
		
	EndIf;
	
	// Set current button by default
	ButtonNext = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandNext");
	
	If ButtonNext <> Undefined Then
		
		ButtonNext.DefaultButton = True;
		
	Else
		
		DoneButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "CommandDone");
		
		If DoneButton <> Undefined Then
			
			DoneButton.DefaultButton = True;
			
		EndIf;
		
	EndIf;
	
	If IsGoNext AND GoToRowCurrent.LongAction Then
		
		AttachIdleHandler("ExecuteLongOperationHandler", 0.1, True);
		
	EndIf;
	
	Iterator = 1;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
	// Transition events handlers
	If IsGoNext Then
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber - Iterator));
		
		If GoToRows.Count() > 0 Then
			
			GoToRow = GoToRows[0];
			
			// handler OnGoingNext
			If Not IsBlankString(GoToRow.GoNextHandlerName)
				AND Not GoToRow.LongAction Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoNextHandlerName);
				
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber - Iterator);
					
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	Else
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber + Iterator));
		
		If GoToRows.Count() > 0 Then
			
			GoToRow = GoToRows[0];
			
			// handler OnGoingBack
			If Not IsBlankString(GoToRow.GoBackHandlerName)
				AND Not GoToRow.LongAction Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoBackHandlerName);
				
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber + Iterator);
					
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page for displaying is not defined.'; ru = '???? ???????????????????? ???????????????? ?????? ??????????????????????.';pl = 'Nie okre??lono strony do wy??wietlenia.';es_ES = 'P??gina para visualizar no se ha definido.';es_CO = 'P??gina para visualizar no se ha definido.';tr = 'G??sterilecek sayfa tan??mlanmad??.';it = 'La pagina per la visualizzazione non ?? stata definita.';de = 'Die Seite f??r die Anzeige ist nicht definiert.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	If GoToRowCurrent.LongAction AND Not IsGoNext Then
		
		SetGoToNumber(GoToNumber - 1);
		Return;
	EndIf;
	
	// handler OnOpen
	If Not IsBlankString(GoToRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, SkipPage, IsGoNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.OnOpenHandlerName);
		
		Cancel = False;
		SkipPage = False;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf SkipPage Then
			
			If IsGoNext Then
				
				SetGoToNumber(GoToNumber + 1);
				
				Return;
				
			Else
				
				SetGoToNumber(GoToNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteLongOperationHandler()
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page for displaying is not defined.'; ru = '???? ???????????????????? ???????????????? ?????? ??????????????????????.';pl = 'Nie okre??lono strony do wy??wietlenia.';es_ES = 'P??gina para visualizar no se ha definido.';es_CO = 'P??gina para visualizar no se ha definido.';tr = 'G??sterilecek sayfa tan??mlanmad??.';it = 'La pagina per la visualizzazione non ?? stata definita.';de = 'Die Seite f??r die Anzeige ist nicht definiert.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	// handler LongOperationHandling
	If Not IsBlankString(GoToRowCurrent.LongOperationHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.LongOperationHandlerName);
		
		Cancel = False;
		GoToNext = True;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf GoToNext Then
			
			SetGoToNumber(GoToNumber + 1);
			
			Return;
			
		EndIf;
		
	Else
		
		SetGoToNumber(GoToNumber + 1);
		
		Return;
		
	EndIf;
	
EndProcedure

// Adds new row to the end of current transitions table
//
// Parameters:
//
//  TransitionSequenceNumber (mandatory) - Number. Sequence number of transition that corresponds
//  to the current MainPageName transition step (mandatory) - String. Page name of the MainPanel panel which corresponds
//  to the current number of transition NavigationPageName (mandatory) - String. Page name of the NavigationPanel panel,
//  which corresponds to the current number of transition DecorationPageName (optional) - String. Page name of the
//  DecorationPanel panel, which corresponds to the current number of transition DeveloperNameOnOpening (optional) -
//  String. Name of the function-processor of the HandlerNameOnGoingNext assistant current page open event (optional) -
//  String. Name of the function-processor of the HandlerNameOnGoingBack transition to the next assistant page event
//  (optional) - String. Name of the function-processor of the LongAction transition to assistant previous page event
//  (optional) - Boolean. Shows displayed long operation page.
//  True - long operation page is displayed; False - show normal page. Value by default - False.
// 
&AtClient
Procedure GoToTableNewRow(GoToNumber,
									MainPageName,
									NavigationPageName,
									DecorationPageName = "",
									OnOpenHandlerName = "",
									GoNextHandlerName = "",
									GoBackHandlerName = "",
									LongAction = False,
									LongOperationHandlerName = "")
	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber = GoToNumber;
	NewRow.MainPageName     = MainPageName;
	NewRow.DecorationPageName    = DecorationPageName;
	NewRow.NavigationPageName    = NavigationPageName;
	
	NewRow.GoNextHandlerName = GoNextHandlerName;
	NewRow.GoBackHandlerName = GoBackHandlerName;
	NewRow.OnOpenHandlerName      = OnOpenHandlerName;
	
	NewRow.LongAction = LongAction;
	NewRow.LongOperationHandlerName = LongOperationHandlerName;
	
EndProcedure

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item In FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			
			If FormItemByCommandName <> Undefined Then
				
				Return FormItemByCommandName;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton")
			AND Find(Item.CommandName, CommandName) > 0 Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

#EndRegion

#Region OverridablePart

#Region TransitionEventsHandlers

//Function
// Connected_PageTwo_OnGoingNext (Denial)
// Function Connected_PageTwo_OnGoingBack (Denial) Function Connected_PageTwo_OnOpen(Denial, SkipPage, Value IsGoingNext)
&AtClient
Function Attachable_PageEmployee1_OnGoingNext(Cancel)
	
	If IsBlankString(Object.Description) Then
		
		MessageText = NStr("en = 'Fill in employee''s full name.'; ru = '???????????????????? ?????????????????? ?????? ????????????????????.';pl = 'Wprowad?? imi?? i nazwisko pracownika.';es_ES = 'Rellenar el nombre completo del empleado.';es_CO = 'Rellenar el nombre completo del empleado.';tr = '??al????an??n tam ad??n?? doldurun.';it = 'Compilare il nome completo del dipendente.';de = 'Geben Sie den vollst??ndigen Namen des Mitarbeiters ein.'");
		CommonClientServer.MessageToUser(MessageText, , "Object.Description", , Cancel);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_PageFL_OnGoingNext(Cancel)
	Var Errors;
	
	CheckInd(Errors);
	
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
EndFunction

&AtClient
Function Attachable_PageEmploymentContract1_OnGoingNext(Cancel)
	Var Errors;
	
	If Not ValueIsFilled(EmploymentContractEmploymentContractDate) Then
		
		MessageText = NStr("en = 'Fill in hiring date.'; ru = '???????????????????? ?????????????????? ???????? ???????????? ???? ????????????.';pl = 'Wprowad?? dat?? zatrudnienia.';es_ES = 'Rellenar la fecha de contrataci??n.';es_CO = 'Rellenar la fecha de contrataci??n.';tr = '????e alma tarihini doldurun.';it = '?? necessario compilare la data di assunzione.';de = 'F??llen Sie das Einstellungsdatum aus.'");
		CommonClientServer.AddUserError(Errors, "EmploymentContractEmploymentContractDate", MessageText, Undefined);
		
	EndIf;
	
	If Not ValueIsFilled(EmploymentContractCompany) Then
		
		MessageText = NStr("en = 'Fill in company.'; ru = '???????????????????? ?????????????????? ??????????????????????.';pl = 'Wprowad?? firm??.';es_ES = 'Rellenar la empresa.';es_CO = 'Rellenar la empresa.';tr = '???? yerini doldurun.';it = 'Riempire il campo azienda.';de = 'Firma ausf??llen.'");
		CommonClientServer.AddUserError(Errors, "EmploymentContractCompany", MessageText, Undefined);
		
	EndIf;
	
	If DepartmentsAreUsed
		AND Not ValueIsFilled(EmploymentContractStructuralUnit) Then
		
		MessageText = NStr("en = 'Fill in department.'; ru = '???????????????????? ?????????????????? ??????????????????????????.';pl = 'Wprowad?? dzia??.';es_ES = 'Rellenar el departamento.';es_CO = 'Rellenar el departamento.';tr = 'B??l??m?? doldurun.';it = 'Compilare il reparto.';de = 'Abteilung ausf??llen.'");
		CommonClientServer.AddUserError(Errors, "EmploymentContractStructuralUnit", MessageText, Undefined);
		
	EndIf;
	
	If Not ValueIsFilled(EmploymentContractPosition) Then
		
		MessageText = NStr("en = 'Fill in employee''s position.'; ru = '???????????????????? ?????????????????? ?????????????????? ????????????????????.';pl = 'Wprowad?? stanowisko pracownika.';es_ES = 'Rellenar el puesto del empleado.';es_CO = 'Rellenar el puesto del empleado.';tr = '??al????an??n pozisyonunu doldurun.';it = 'Compilare la posizione del dipendente.';de = 'F??llen Sie die Position des Mitarbeiters aus.'");
		CommonClientServer.AddUserError(Errors, "EmploymentContractPosition", MessageText, Undefined);
		
	EndIf;
	
	If UsedStaffSchedule Then
		
		If Not ValueIsFilled(EmploymentContractOccupiedRates) Then
			
			MessageText = NStr("en = 'Fill in quantity of held rates.'; ru = '???????????????????? ?????????????????? ???????????????????? ???????????????????? ????????????.';pl = 'Wprowad?? ilo???? posiadanych stawek.';es_ES = 'Rellenar la cantidad de las tasas retenidas.';es_CO = 'Rellenar la cantidad de las tasas retenidas.';tr = 'Dolu pozisyonlar??n say??s??n?? doldurun.';it = 'E'' necessario compilare il numero di tasso di occupazione.';de = 'F??llen Sie die Menge der gehaltenen Raten aus.'");
			CommonClientServer.AddUserError(Errors, "EmploymentContractOccupiedRates", MessageText, Undefined);
			
		Else
			
			DataStructure = New Structure;
			DataStructure.Insert("EmploymentContractDate", EmploymentContractEmploymentContractDate);
			DataStructure.Insert("Company", EmploymentContractCompany);
			DataStructure.Insert("StructuralUnit", EmploymentContractStructuralUnit);
			DataStructure.Insert("Position", EmploymentContractPosition);
			DataStructure.Insert("PlannedTakeRates", EmploymentContractOccupiedRates);
			DataStructure.Insert("AddRates", EmploymentContractAddRates);
			
			RunControlStaffSchedule(DataStructure, Errors, Cancel);
			
		EndIf;
		
	EndIf;
	
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
EndFunction

&AtClient
Function Attachable_PageEmploymentContract2_OnGoingNext(Cancel)
	Var Errors;
	
	If EarningsDeductions.Count() < 1 Then
		
		MessageText = NStr("en = 'Fill in the table of earnings and deductions.'; ru = '???????????????????? ?????????????????? ?????????????? ???????????????????? ?? ??????????????????.';pl = 'Wype??nij tabel?? zarobk??w i potr??ce??.';es_ES = 'Rellenar la tabla de ingresos y deducciones.';es_CO = 'Rellenar la tabla de ingresos y deducciones.';tr = 'Kesinti ve kazan?? tablosunu doldurun.';it = 'Compilare la tabella di compensi e trattenute.';de = 'F??llen Sie die Tabelle der Bez??ge und Abz??ge aus.'");
		CommonClientServer.AddUserError(Errors, "EarningsDeductions", MessageText, Undefined);
		
	EndIf;
	
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
EndFunction

&AtClient
Function PageWritten_OnGoingNext()
	
	If CreateApplicationUser Then
		
		FillingValues = New Structure("Description", Object.Description);
		OpenForm("Catalog.Users.ObjectForm", New Structure("FillingValues", FillingValues));
		
	EndIf;
	
EndFunction

// Next transfer handler (to the next page) on leaving WaitingPage assistant page
//
// Parameters:
// Cancel - Boolean - no going next check box;
// 				if you select this check box in the handler, you will not be transferred to the next page.
//
&AtClient
Function Attachable_WaitPage_LongOperationProcessing(Cancel, GoToNext)
	
	ExecuteLongOperationAtServer();
	
EndFunction

&AtServer
Procedure ExecuteLongOperationAtServer()
	
	Try
		
		BeginTransaction(DataLockControlMode.Managed);
		
		Block				= New DataLock;
		DataLockItem		= Block.Add("Catalog.Employees");
		DataLockItem.Mode	= DataLockMode.Shared;
		
		If AssociateWithIndividual AND FillVariant = 1 Then		
			DataLockItem = Block.Add("Catalog.Individuals");
			DataLockItem.Mode = DataLockMode.Shared;		
		EndIf;
		
		If AcceptForEmploymentContract Then		
			DataLockItem = Block.Add("Document.EmploymentContract");
			DataLockItem.Mode = DataLockMode.Shared;			
		EndIf;
		
		Block.Lock();
		
		// Individual record
		EventLogMonitorEvent = NStr("en = 'New employee ind. entry'; ru = '???????????? ??????. ???????? ???????????? ????????????????????';pl = 'Zapis nowego pracownika, osoby fizycznej';es_ES = 'Nuevo empleado indicado entrada';es_CO = 'Nuevo empleado indicado entrada';tr = 'Yeni ??al????an??n ger??ek ki??inin kayd??';it = 'Registrazione dell''assunzione di un nuovo dipendente';de = 'Neuer Mitarbeiter ind. Eintrag'", CommonClientServer.DefaultLanguageCode());
		If AssociateWithIndividual AND FillVariant = 1 Then
			
			NewInd = Catalogs.Individuals.CreateItem();
			NewInd.Description	= IndFirstName + " " + IndLastName;
			NewInd.FirstName	= IndFirstName;
			NewInd.LastName		= IndLastName;
			NewInd.Gender		= NewFLGender;
			NewInd.BirthDate	= NewFLBirthDate;
			NewInd.Write();
			
			Object.Ind = NewInd.Ref;
			
		EndIf;
	
		// Employee record
		EventLogMonitorEvent	= NStr("en = 'New employee record'; ru = '???????????? ???????????? ????????????????????';pl = 'Zapis nowego pracownika';es_ES = 'Registro de un nuevo empleado';es_CO = 'Registro de un nuevo empleado';tr = 'Yeni ??al????an??n kayd??';it = 'Registrazione di un nuovo dipendente';de = 'Neuen Mitarbeiter erfassen'", CommonClientServer.DefaultLanguageCode());
		NewEmployee				= Catalogs.Employees.CreateItem();
		FillPropertyValues(NewEmployee, Object);
		NewEmployee.Parent		= Parent;
		NewEmployee.Write();
		
		// EmploymentContract
		If AcceptForEmploymentContract Then
			
			EventLogMonitorEvent = NStr("en = 'Add rates to staff list'; ru = '???????????????????? ???????????? ?? ?????????????? ????????????????????';pl = 'Dodanie stawki do wykazu etat??w.';es_ES = 'A??adir tasas a la lista de empleados';es_CO = 'A??adir tasas a la lista de empleados';tr = 'Personel ??izelgesine pozisyonlar?? ekle';it = 'Aggiunta i tassi all''elenco del personale';de = 'Raten zur Mitarbeiterliste hinzuf??gen'", CommonClientServer.DefaultLanguageCode());
			If UsedStaffSchedule
				AND RatesFree < EmploymentContractOccupiedRates 
				AND EmploymentContractAddRates Then
				
				Filter = New Structure("Company, StructuralUnit, Position", EmploymentContractCompany, EmploymentContractStructuralUnit, EmploymentContractPosition);
				RecordsTable = InformationRegisters.HeadcountBudget.SliceLast(EmploymentContractEmploymentContractDate, Filter);
				
				RecordManager = InformationRegisters.HeadcountBudget.CreateRecordManager();
				RecordManager.Period				= EmploymentContractEmploymentContractDate;
				RecordManager.Company				= EmploymentContractCompany;
				RecordManager.StructuralUnit		= EmploymentContractStructuralUnit;
				RecordManager.Position				= EmploymentContractPosition;
				RecordManager.TariffRateCurrency	= EmploymentContractCurrency;
				
				If RecordsTable.Count() <> 0 Then
					
					RecordManager.NumberOfRates			= RecordsTable[0].NumberOfRates + ?(RatesFree < 0, RatesFree * -1, RatesFree) + EmploymentContractOccupiedRates;
					RecordManager.EarningAndDeductionType	= RecordsTable[0].EarningAndDeductionType;
					RecordManager.MinimumTariffRate		= RecordsTable[0].MinimumTariffRate;
					RecordManager.MaximumTariffRate		= RecordsTable[0].MaximumTariffRate;
					
				Else
					
					RecordManager.NumberOfRates = ?(RatesFree < 0, RatesFree * -1, RatesFree) + EmploymentContractOccupiedRates;
					
				EndIf;
				
				RecordManager.Write(True);
				
			EndIf;
			
			EventLogMonitorEvent			= NStr("en = 'New employee hiring entry'; ru = '???????????? ???????????? ???? ???????????? ???????????? ????????????????????';pl = 'Wpis o zatrudnieniu nowego pracownika';es_ES = 'Entrada de contrataci??n de un nuevo empleado';es_CO = 'Entrada de contrataci??n de un nuevo empleado';tr = 'Yeni ??al????an??n istihdam kayd??';it = 'Registrazione dell''assunzione di un nuovo dipendente';de = 'Neuer Anstellungseintrag f??r Mitarbeiter'", CommonClientServer.DefaultLanguageCode());
			EmploymentContractObject		= Documents.EmploymentContract.CreateDocument();
			EmploymentContractObject.Date	= CurrentSessionDate();
			DriveServer.FillDocumentHeader(EmploymentContractObject,,,, True);
			EmploymentContractObject.Company= EmploymentContractCompany;
			
			EmployeesPage					= EmploymentContractObject.Employees.Add();
			EmployeesPage.Period			= EmploymentContractEmploymentContractDate;
			EmployeesPage.Employee			= NewEmployee.Ref;
			EmployeesPage.StructuralUnit	= EmploymentContractStructuralUnit;
			EmployeesPage.Position			= EmploymentContractPosition;
			EmployeesPage.WorkSchedule		= EmploymentContractWorkSchedule;
			EmployeesPage.OccupiedRates		= EmploymentContractOccupiedRates;
			EmployeesPage.ConnectionKey		= 1;
			
			For Each TSRow In EarningsDeductions Do
				
				If ValueIsFilled(TSRow.EarningAndDeductionType) Then
					
					RowEarning						= EmploymentContractObject.EarningsDeductions.Add();
					FillPropertyValues(RowEarning, TSRow);
					RowEarning.Amount				= TSRow.Amount;
					RowEarning.Currency				= EmploymentContractCurrency;
					RowEarning.GLExpenseAccount		= TSRow.GLExpenseAccount;
					RowEarning.ConnectionKey		= 1;
					
				EndIf; 
				
			EndDo;
			
			EmploymentContractObject.Write(DocumentWriteMode.Posting);
			
		EndIf;
		
		CommitTransaction();
		
	Except
		
		If TransactionActive() Then
			RollbackTransaction();
		EndIf;
		
		WriteLogEvent(EventLogMonitorEvent, EventLogLevel.Error, Metadata.Catalogs.Employees, , ErrorDescription());
		
	EndTry;
	
EndProcedure

&AtServer
// Controls staff list
//
Procedure RunControlStaffSchedule(DataStructure, Errors, Cancel)
	
	Query = New Query(
	"SELECT ALLOWED
	|	StaffScheduleSliceLast.NumberOfRates AS NumberOfRates,
	|	StaffScheduleSliceLast.MinimumTariffRate,
	|	StaffScheduleSliceLast.MaximumTariffRate,
	|	StaffScheduleSliceLast.EarningAndDeductionType,
	|	StaffScheduleSliceLast.TariffRateCurrency
	|FROM
	|	InformationRegister.HeadcountBudget.SliceLast(
	|			&Period,
	|			Company = &Company
	|				AND StructuralUnit = &StructuralUnit
	|				AND Position = &Position) AS StaffScheduleSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SUM(OccupiedRates.OccupiedRates1) AS OccupiedRates
	|FROM
	|	(SELECT
	|		SUM(EmployeesSliceLast.OccupiedRates) AS OccupiedRates1,
	|		MAX(EmployeesSliceLast.Period) AS Period,
	|		EmployeesSliceLast.Company AS Company,
	|		EmployeesSliceLast.StructuralUnit AS StructuralUnit,
	|		EmployeesSliceLast.Position AS Position
	|	FROM
	|		InformationRegister.Employees.SliceLast(&Period, ) AS EmployeesSliceLast
	|	
	|	GROUP BY
	|		EmployeesSliceLast.Company,
	|		EmployeesSliceLast.StructuralUnit,
	|		EmployeesSliceLast.Position) AS OccupiedRates
	|WHERE
	|	OccupiedRates.Company = &Company
	|	AND OccupiedRates.StructuralUnit = &StructuralUnit
	|	AND OccupiedRates.Position = &Position");
	
	Query.SetParameter("Period", 		DataStructure.EmploymentContractDate);
	Query.SetParameter("Company",	DataStructure.Company);
	Query.SetParameter("StructuralUnit", DataStructure.StructuralUnit);
	Query.SetParameter("Position", 		DataStructure.Position);
	
	BatchQueryExecutionResult = Query.ExecuteBatch();
	SelectionNumberOfRates = BatchQueryExecutionResult[0].Select();
	SampleReservedRates = BatchQueryExecutionResult[1].Select();
	
	MessageText = "";
	If DataStructure.AddRates Then // If you select add positions option, there will be no mistakes in absence of vacant positions.
		
		SelectionNumberOfRates.Next();
		SampleReservedRates.Next();
		RatesFree = ?(ValueIsFilled(SelectionNumberOfRates.NumberOfRates), SelectionNumberOfRates.NumberOfRates, 0) - ?(ValueIsFilled(SampleReservedRates.OccupiedRates), SampleReservedRates.OccupiedRates, 0);
		
	ElsIf Not SelectionNumberOfRates.Next() Then
		
		MessageText = NStr("en = 'Rates for position %3 are not available in the staff list of company %2 by business unit %2.'; ru = '?? ?????????????? ???????????????????? ?????????????????????? %2 ???? ?????????????????????? ?????????????? %2 ???? ?????????????????????????? ???????????? ?????? ?????????????????? %3!';pl = 'Dla stanowiska %3 nie ma stawki w wykazie etat??w firmy %2 dla jednostki biznesowej %2.';es_ES = 'Tasas para el puesto %3 no est??n disponibles en la lista de empleados de la empresa %2 por la unidad empresarial %2.';es_CO = 'Tasas para el puesto %3 no est??n disponibles en la lista de empleados de la empresa %2 por la unidad de negocio %2.';tr = '%3???? yerinin personel listesinde yap??sal biriminde %2, %2 pozisyonu i??in bo?? kadro ??ng??r??lmemi??tir.';it = 'I tassi per la posizione %3 non sono disponibili nell''elenco del personale dell''azienda %2 per business unit %2.';de = 'Die Raten f??r die Position %3 sind in der Mitarbeiterliste der Firma %2 nach Abteilungen nicht verf??gbar %2.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, DataStructure.Company, DataStructure.StructuralUnit, DataStructure.Position);
		
	Else
		
		SampleReservedRates.Next();
		RatesFree = SelectionNumberOfRates.NumberOfRates - ?(ValueIsFilled(SampleReservedRates.OccupiedRates), SampleReservedRates.OccupiedRates, 0);
		
		If RatesFree < DataStructure.PlannedTakeRates Then
			
			MessageText = NStr("en = 'There''s not enough vacant positions for job %3 according to business unit %2 in the company %1 staff list.
			                   |Vacant positions %4, required positions %5.'; 
			                   |ru = '?? ?????????????? ???????????????????? ?????????????????????? %1 ???? ?????????????????????? ?????????????? %2 ?????? ???????????????????????? ???????????????????? ?????????????????? ???????????? ?????? ?????????????????? %3.
			                   |???????????????? ???????????? %4, ?? ?????????????????? ???????????? %5.';
			                   |pl = 'Nie ma wystarczaj??cej ilo??ci etat??w dla stanowiska %3 dla jednostki biznesowej %2 w wykazie %1 etat??w firmy.
			                   | Jest %4 etat??w, potrzebne jest %5.';
			                   |es_ES = 'No hay suficientes puestos vacantes para esta posici??n %3 seg??n la unidad empresarial %2 en el listado de empleados %1 de la empresa.
			                   |Puestos vacantes %4, posiciones requeridas %5.';
			                   |es_CO = 'No hay suficientes puestos vacantes para esta posici??n %3 seg??n la unidad de negocio %2 en el listado de empleados %1 de la empresa.
			                   |Puestos vacantes %4, posiciones requeridas %5.';
			                   |tr = '???? yeri %1 personeli listesindeki departmana %2 g??re %3 i??i i??in yeterli bo?? pozisyon yok. 
			                   | Bo?? pozisyonlar %4, gerekli pozisyonlar %5.';
			                   |it = 'Non ci sono sufficienti posizioni aperte per il lavoro %3 secondo il business unit %2 nell''elenco personale dell''azienda %1.
			                   |Posizioni aperte %4, posizioni richieste %5.';
			                   |de = 'F??r die Stelle %3 nach Abteilung %2 gibt es in der Mitarbeiterliste der Firma %1 nicht gen??gend freie Stellen.
			                   |Offene Positionen %4, ben??tigte Positionen %5.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, DataStructure.Company, DataStructure.StructuralUnit, DataStructure.Position, RatesFree, DataStructure.PlannedTakeRates);
			
		EndIf;
		
	EndIf;
	
	If Not IsBlankString(MessageText) Then
		
		CommonClientServer.AddUserError(Errors, , MessageText, Undefined);
		Cancel = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckInd(Errors)
	
	If AssociateWithIndividual AND FillVariant = 1 Then
		
		If NOT ValueIsFilled(IndLastName) Then
			MessageText = NStr("en = 'Please enter the last name of the employee.'; ru = '????????????????????, ?????????????????? ?????????????? ????????????????????.';pl = 'Wprowad?? nazwisko pracownika.';es_ES = 'Por favor, introducir el apellido del empleado.';es_CO = 'Por favor, introducir el apellido del empleado.';tr = 'L??tfen, ??al????an??n soyad??n?? girin.';it = 'Per piacere inserite il cognome del dipendente.';de = 'Bitte geben Sie den Nachnamen des Mitarbeiters ein.'");
			CommonClientServer.AddUserError(Errors,, MessageText, Undefined);
		EndIf;

		If NOT ValueIsFilled(IndFirstName) Then
			MessageText = NStr("en = 'Please enter the first name of the employee.'; ru = '????????????????????, ?????????????????? ?????? ????????????????????.';pl = 'Wprowad?? imi?? pracownika.';es_ES = 'Por favor, introducir el nombre del empleado.';es_CO = 'Por favor, introducir el nombre del empleado.';tr = 'L??tfen, ??al????an??n ad??n?? doldurun.';it = 'Per piacere inserite il nome del dipendente.';de = 'Bitte geben Sie den Vornamen des Mitarbeiters ein.'");
			CommonClientServer.AddUserError(Errors,, MessageText, Undefined);
		EndIf;
		
	EndIf;
	
		
	If Object.EmploymentContractType = Enums.EmploymentContractTypes.FullTime
		AND ValueIsFilled(Object.Ind) Then
		
		MessageText = "";
		Query		= New Query;
		Query.SetParameter("Ind", Object.Ind);
		
		Query.Text = 
		"SELECT ALLOWED
		|	MAX(Employees.Period) AS DateOfReception,
		|	Employees.Employee.Ind AS Ind,
		|	Employees.Employee AS MainStaff
		|FROM
		|	InformationRegister.Employees AS Employees
		|WHERE
		|	Employees.Employee.EmploymentContractType = VALUE(Enum.EmploymentContractTypes.FullTime)
		|	AND Employees.Employee.Ind = &Ind
		|
		|GROUP BY
		|	Employees.Employee,
		|	Employees.Employee.Ind";
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			MessageText = NStr("en = 'There is already full-time employee exists for selected individual.'; ru = '???????????????????? ????????, ?? ???????????????? ?????????????? ???????????????? ????????????????????, ?????? ?????????? ???????????????????? ?? ???????????????? ???????????? ????????????.';pl = 'Dla wybranej osoby fizycznej istnieje ju?? pe??noetatowy pracownik.';es_ES = 'Ya existe un empleado a jornada completa para el particular seleccionado.';es_CO = 'Ya existe un empleado a jornada completa para el particular seleccionado.';tr = 'Mevcut ??al????an??n ait oldu??u ger??ek ki??i, tam zamanl?? ??al????ana sahiptir.';it = 'La persona fisica a cui si riferisce l''attuale dipendente ha gi?? un dipendente con il posto di lavoro principale.';de = 'F??r die ausgew??hlte nat??rliche Person existiert bereits ein Vollzeit-Mitarbeiter.'");
			CommonClientServer.AddUserError(Errors, , MessageText, Undefined);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InitializeAssistantTransitions

// Procedure defines scripted transitions table No1.
// To fill transitions table, use TransitionsTableNewRow()procedure
//
&AtClient
Procedure Scenario1GoToTable()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "PageEmployee1", "NavigationPageStart", "DecorationPageStart", , "PageEmployee1_OnGoingNext");
	GoToTableNewRow(2, "PageEmployee2", "NavigationPageContinuation", "DecorationPageContinuation");
	GoToTableNewRow(3, "PageFL", "NavigationPageContinuation", "DecorationPageContinuation", , "PageFL_OnGoingNext");
	GoToTableNewRow(4, "PageEmploymentContract1", "NavigationPageContinuation", "DecorationPageContinuation", , "PageEmploymentContract1_OnGoingNext");
	GoToTableNewRow(5, "PageEmploymentContract2", "NavigationPageContinuation", "DecorationPageContinuation", , "PageEmploymentContract2_OnGoingNext");
	GoToTableNewRow(6, "WaitPage", "NavigationPageWait", "DecorationPageContinuation",,,, True, "WaitPage_LongOperationProcessing");
	GoToTableNewRow(7, "PageWritten", "NavigationPageEnd", "DecorationPageEnd", , "PageWritten_OnGoingNext");
	
EndProcedure

#EndRegion

#EndRegion

#EndRegion

#Region Private

&AtServer
Function GenerateShamObject()

	ObjectParameters = New Structure;
	ObjectParameters.Insert("Company", EmploymentContractCompany);
	ObjectParameters.Insert("Date", EmploymentContractEmploymentContractDate);
	ObjectParameters.Insert("DocumentName", "EmploymentContract");
	ObjectParameters.Insert("Ref", Documents.EmploymentContract.EmptyRef());
	ObjectParameters.Insert("StructuralUnit", EmploymentContractStructuralUnit);
	
	Return ObjectParameters;
	
EndFunction

&AtClient
Procedure IncomeAndExpenseItemsChoiceProcessing(Form, Items) 

	DocObject = Form.Object;
	TabName = Items.TableName;
	
	TabRow = Form.Items[TabName].CurrentData;
	
	FillPropertyValues(TabRow, Items);
	Form.Modified = True;
	
	If TabName = "Header" Then
		FillPropertyValues(Form, Items);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function IsExpenseTypeOfEarningAndDeductionType(EarningAndDeductionType)
	Return Common.ObjectAttributeValue(EarningAndDeductionType, "Type") = Enums.EarningAndDeductionTypes.Earning;
EndFunction

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = GenerateShamObject();
	
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	StructureEarningsDeductions = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "EarningsDeductions");
	GLAccountsInDocuments.CompleteStructureData(StructureEarningsDeductions, ObjectParameters, "EarningsDeductions");
	
	StructureArray.Add(StructureEarningsDeductions);
	
	DocObject = New Structure;
	DocObject.Insert("EarningsDeductions", EarningsDeductions);
	
	GLAccountsInDocuments.FillGLAccountsInArray(DocObject, StructureArray, GetGLAccounts);
	
EndProcedure

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion