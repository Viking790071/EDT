#Region GeneralPurposeProceduresAndFunctions

&AtServer
// Function forms and performs query.
//
Function ExecuteQuery()
	
	SetPrivilegedMode(True);
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	EarningsAndDeductions.Employee AS Ind,
	|	EarningsAndDeductions.Employee.Code AS EmployeeCode,
	|	EarningsAndDeductions.StructuralUnit AS Department,
	|	EarningsAndDeductions.StructuralUnit.Description AS DepartmentPresentation,
	|	EmployeesSliceLast.Position AS Position,
	|	CASE
	|		WHEN EarningsAndDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN EarningsAndDeductions.EarningAndDeductionType
	|		ELSE NULL
	|	END AS Earning,
	|	CASE
	|		WHEN EarningsAndDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN NULL
	|		ELSE EarningsAndDeductions.EarningAndDeductionType
	|	END AS Deduction,
	|	SUM(CASE
	|			WHEN EarningsAndDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|				THEN ISNULL(EarningsAndDeductions.AmountCur, 0)
	|			ELSE 0
	|		END) AS AmountAccrued,
	|	SUM(CASE
	|			WHEN EarningsAndDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|				THEN 0
	|			ELSE ISNULL(EarningsAndDeductions.AmountCur, 0)
	|		END) AS AmountWithheld,
	|	CASE
	|		WHEN EarningsAndDeductions.EarningAndDeductionType = VALUE(Catalog.EarningAndDeductionTypes.PieceRatePay)
	|				OR EarningsAndDeductions.EarningAndDeductionType = VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayPercent)
	|			THEN &RegistrationPeriod
	|		ELSE EarningsAndDeductions.StartDate
	|	END AS StartDate,
	|	CASE
	|		WHEN EarningsAndDeductions.EarningAndDeductionType = VALUE(Catalog.EarningAndDeductionTypes.PieceRatePay)
	|				OR EarningsAndDeductions.EarningAndDeductionType = VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayPercent)
	|			THEN ENDOFPERIOD(&RegistrationPeriod, MONTH)
	|		ELSE EarningsAndDeductions.EndDate
	|	END AS EndDate,
	|	SUM(EarningsAndDeductions.DaysWorked) AS DaysWorked,
	|	SUM(EarningsAndDeductions.HoursWorked) AS HoursWorked,
	|	ISNULL(DebtAtEnd.AmountCurBalance, 0) AS ClosingBalance,
	|	ISNULL(DebtToBegin.AmountCurBalance, 0) AS BalanceAtBegin,
	|	ChangeHistoryOfIndividualNamesSliceLast.Surname AS Surname,
	|	ChangeHistoryOfIndividualNamesSliceLast.Name AS Name,
	|	ChangeHistoryOfIndividualNamesSliceLast.Patronymic AS Patronymic,
	|	CASE
	|		WHEN ISNULL(ChangeHistoryOfIndividualNamesSliceLast.Surname, """") <> """"
	|			THEN ChangeHistoryOfIndividualNamesSliceLast.Surname + "" "" + ChangeHistoryOfIndividualNamesSliceLast.Name + "" "" + ChangeHistoryOfIndividualNamesSliceLast.Patronymic
	|		ELSE EarningsAndDeductions.Employee.Description
	|	END AS EmployeePresentation
	|FROM
	|	AccumulationRegister.EarningsAndDeductions AS EarningsAndDeductions
	|		LEFT JOIN AccumulationRegister.Payroll.Balance(
	|				&RegistrationPeriod,
	|				Company = &Company
	|					AND Currency = &Currency
	|					" + ?(Not ValueIsFilled(Department), "", "AND StructuralUnit = &Department") + ") AS DebtToBegin 
	|		ON EarningsAndDeductions.Employee = DebtToBegin.Employee 
	|			AND EarningsAndDeductions.StructuralUnit = DebtToBegin.StructuralUnit 
	|		LEFT JOIN AccumulationRegister.Payroll.Balance( 
	|				&RegistrationEndOfPeriod, 
	|				Company = &Company 
	|					AND Currency = &Currency
	|					" + ?(Not ValueIsFilled(Department), "", "AND StructuralUnit = &Department") + ") AS DebtAtEnd 
	|		ON EarningsAndDeductions.Employee = DebtAtEnd.Employee 
	|			AND EarningsAndDeductions.StructuralUnit = DebtAtEnd.StructuralUnit 
	|		LEFT JOIN InformationRegister.Employees.SliceLast(
	|				&RegistrationEndOfPeriod, 
	|				Company = &Company 
	|					AND StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)) AS EmployeesSliceLast 
	|		ON EarningsAndDeductions.Employee = EmployeesSliceLast.Employee
	|		LEFT JOIN InformationRegister.ChangeHistoryOfIndividualNames.SliceLast(&RegistrationEndOfPeriod, ) AS ChangeHistoryOfIndividualNamesSliceLast 
	|		ON EarningsAndDeductions.Employee.Ind = ChangeHistoryOfIndividualNamesSliceLast.Ind
	|WHERE 
	|	EarningsAndDeductions.Company = &Company 
	|	AND EarningsAndDeductions.RegistrationPeriod = &RegistrationPeriod 
	|	AND EarningsAndDeductions.Currency = &Currency" + ?(Not ValueIsFilled(Department), "", "
	|	AND EarningsAndDeductions.StructuralUnit = &Department") + " " + ?(Not ValueIsFilled(Employee), "", "
	|	AND EarningsAndDeductions.Employee = &Employee") + "
	|
	|GROUP BY
	|	EarningsAndDeductions.Employee.Code,
	|	CASE
	|		WHEN EarningsAndDeductions.EarningAndDeductionType = VALUE(Catalog.EarningAndDeductionTypes.PieceRatePay)
	|				OR EarningsAndDeductions.EarningAndDeductionType = VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayPercent)
	|			THEN &RegistrationPeriod
	|		ELSE EarningsAndDeductions.StartDate
	|	END,
	|	CASE
	|		WHEN EarningsAndDeductions.EarningAndDeductionType = VALUE(Catalog.EarningAndDeductionTypes.PieceRatePay)
	|				OR EarningsAndDeductions.EarningAndDeductionType = VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayPercent)
	|			THEN ENDOFPERIOD(&RegistrationPeriod, MONTH)
	|		ELSE EarningsAndDeductions.EndDate
	|	END,
	|	EarningsAndDeductions.Employee,
	|	EarningsAndDeductions.StructuralUnit,
	|	EarningsAndDeductions.StructuralUnit.Description,
	|	EmployeesSliceLast.Position,
	|	ISNULL(DebtAtEnd.AmountCurBalance, 0),
	|	ISNULL(DebtToBegin.AmountCurBalance, 0),
	|	ChangeHistoryOfIndividualNamesSliceLast.Surname,
	|	ChangeHistoryOfIndividualNamesSliceLast.Name,
	|	ChangeHistoryOfIndividualNamesSliceLast.Patronymic,
	|	CASE
	|		WHEN EarningsAndDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN EarningsAndDeductions.EarningAndDeductionType
	|		ELSE NULL
	|	END,
	|	CASE
	|		WHEN EarningsAndDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN NULL
	|		ELSE EarningsAndDeductions.EarningAndDeductionType
	|	END,
	|	CASE
	|		WHEN ISNULL(ChangeHistoryOfIndividualNamesSliceLast.Surname, """") <> """"
	|			THEN ChangeHistoryOfIndividualNamesSliceLast.Surname + "" "" + ChangeHistoryOfIndividualNamesSliceLast.Name + "" "" + ChangeHistoryOfIndividualNamesSliceLast.Patronymic
	|		ELSE EarningsAndDeductions.Employee.Description
	|	END
	|
	|ORDER BY
	|	DepartmentPresentation,
	|	EmployeePresentation,
	|	StartDate
	|TOTALS
	|	MAX(DepartmentPresentation),
	|	MAX(Position),
	|	SUM(AmountAccrued),
	|	SUM(AmountWithheld),
	|	AVG(ClosingBalance),
	|	AVG(BalanceAtBegin),
	|	MAX(Surname),
	|	MAX(Name),
	|	MAX(Patronymic)
	|BY
	|	Department,
	|	Ind
	|
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CASE
	|		WHEN PayrollTurnovers.Recorder REFS Document.CashVoucher
	|			THEN ""Through petty cash ""
	|		ELSE ""From account ""
	|	END AS DocumentPresentation,
	|	CASE
	|		WHEN PayrollTurnovers.Recorder.BasisDocument REFS Document.PayrollSheet
	|				AND PayrollTurnovers.Recorder.BasisDocument.OperationKind = VALUE(Enum.OperationTypesPayrollSheet.Advance)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AdvanceFlag,
	|	PayrollTurnovers.Recorder.Number As Number,
	|	PayrollTurnovers.Recorder.Date AS Date,
	|	PayrollTurnovers.Recorder,
	|	PayrollTurnovers.Employee,
	|	PayrollTurnovers.AmountCurExpense AS PaymentAmount
	|FROM
	|	AccumulationRegister.Payroll.Turnovers(
	|			&RegistrationPeriod,
	|			&RegistrationEndOfPeriod,
	|			Record,
	|			Company = &Company
	|				AND Currency = &Currency" + ?(Not ValueIsFilled(Department), "", "
	|				AND StructuralUnit = &Department") + " " + ?(Not ValueIsFilled(Employee), "", "
	|				AND Employee = &Employee") + ") AS PayrollTurnovers
	|WHERE 
	|	(PayrollTurnovers.Recorder REFS Document.PaymentExpense 
	|			OR PayrollTurnovers.Recorder REFS Document.PaymentExpense)
	|ORDER BY
	|	PayrollTurnovers.Recorder.BasisDocument.Date, 
	|	PayrollTurnovers.Recorder.Date";
	
	Query.SetParameter("Currency", Currency);
	Query.SetParameter("Company", Company);
	Query.SetParameter("RegistrationPeriod", RegistrationPeriod);
	Query.SetParameter("RegistrationEndOfPeriod", EndOfMonth(RegistrationPeriod)); 
	Query.SetParameter("Department", Department);
	Query.SetParameter("Employee", Employee);
	QueryResult = Query.ExecuteBatch();
	
	SetPrivilegedMode(False);
	
	Return QueryResult;

EndFunction

&AtServer
// Procedure forms the report.
//
Procedure MakeExecute()

	If Constants.UseSeveralCompanies.Get() AND Not ValueIsFilled(Company) Then
		MessageText = NStr("en = 'Company is not selected.'; ru = 'Не выбрана организация!';pl = 'Nie wybrano firmy.';es_ES = 'Empresa no se ha seleccionado.';es_CO = 'Empresa no se ha seleccionado.';tr = 'İş yeri seçilmedi.';it = 'Azienda non selezionata.';de = 'Firma ist nicht ausgewählt.'");
		MessageField = "Company";
		DriveServer.ShowMessageAboutError(Report, MessageText,,,MessageField);
		Return;
	EndIf;

	If Not ValueIsFilled(RegistrationPeriod) Then
		MessageText = NStr("en = 'The registration period is required.'; ru = 'Не выбран период регистрации!';pl = 'Wymagany jest okres rejestracji.';es_ES = 'Se requiere el período de registro.';es_CO = 'Se requiere el período de registro.';tr = 'Kayıt süresi gereklidir.';it = 'Il periodo di registrazione è necessario.';de = 'Der Registrierungszeitraum ist erforderlich.'");
		MessageField = "RegistrationPeriod";
		DriveServer.ShowMessageAboutError(Report, MessageText,,,MessageField);
		Return;
	EndIf;

	If Not Constants.ForeignExchangeAccounting.Get() AND Not ValueIsFilled(Currency) Then
		MessageText = NStr("en = 'Currency is not selected.'; ru = 'Не выбрана валюта!';pl = 'Nie wybrano waluty.';es_ES = 'Moneda no está seleccionada.';es_CO = 'Moneda no está seleccionada.';tr = 'Para birimi seçilmemiş.';it = 'Valuta non selezionata.';de = 'Währung ist nicht ausgewählt.'");
		MessageField = "Currency";
		DriveServer.ShowMessageAboutError(Report, MessageText,,,MessageField);
		Return;
	EndIf;

	QueryResult = ExecuteQuery();

	If QueryResult[0].IsEmpty() Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'No data to generate the report.'; ru = 'Нет данных для формирования отчета!';pl = 'Brak danych do utworzenia raportu.';es_ES = 'No hay datos para generar el informe.';es_CO = 'No hay datos para generar el informe.';tr = 'Raporu oluşturmak için veri yok.';it = 'Non ci sono dati per generare il report.';de = 'Keine Daten zum Generieren des Berichts.'");
		Message.Message();
		Return;
	EndIf;

	Template = Reports.PaySlips.GetTemplate("Template");

	AreaHeader 				= Template.GetArea("Header");
	HeaderArea 			= Template.GetArea("Title");
	AreaDetails 				= Template.GetArea("Details");
	AreaIncomePayed 		= Template.GetArea("IncomePaid");
	AreaPaymentDetails 		= Template.GetArea("DetailsPayment");
	AreaTotal 				= Template.GetArea("Total");
	FooterArea 				= Template.GetArea("Footer");
	AreaSpace 				= Template.GetArea("Spacing");

	SpreadsheetDocument.Clear();

    AreaSpace.Parameters.TextPadding = Format(RegistrationPeriod , "DF='MMMM yyyy'");
	SpreadsheetDocument.Put(AreaSpace);

    AreaSpace.Parameters.TextPadding = Nstr("en = 'Company:'; ru = 'Организация:';pl = 'Firma:';es_ES = 'Empresa:';es_CO = 'Empresa:';tr = 'İş yeri:';it = 'Azienda:';de = 'Firma:'") + " " + Company;
	SpreadsheetDocument.Put(AreaSpace);

	SelectionSubdepartment = QueryResult[0].Select(QueryResultIteration.ByGroups, "Department");
	While SelectionSubdepartment.Next() Do

        AreaSpace.Parameters.TextPadding = Nstr("en = 'Department:'; ru = 'Подразделение:';pl = 'Dział:';es_ES = 'Departamento:';es_CO = 'Departamento:';tr = 'Bölüm:';it = 'Reparto:';de = 'Abteilung:'") + " " + SelectionSubdepartment.Department;
		SpreadsheetDocument.Put(AreaSpace);
        SpreadsheetDocument.StartRowGroup();
		
		IndividualSelection = SelectionSubdepartment.Select(QueryResultIteration.ByGroups, "Ind");
		While IndividualSelection.Next() Do

			AreaHeader.Parameters.Title = StringFunctionsClientServer.SubstituteParametersToString(
				Nstr("en = 'Payslip for the period of %1.'; ru = 'Расчетные листки за период %1.';pl = 'Pasek wynagrodzenia za okres %1.';es_ES = 'Nómina para el período de %1.';es_CO = 'Nómina para el período de %1.';tr = ' %1 dönemi için maaş bordrosu.';it = 'Cedolino per il periodo %1.';de = 'Lohnzettel für den Zeitraum von %1.'"), 
				Format(RegistrationPeriod, "DF='MMMM yyyy'"));
			AreaHeader.Parameters.Company = Company;
			AreaHeader.Parameters.Fill(IndividualSelection);
			PresentationIndividual = DriveServer.GetSurnameNamePatronymic(IndividualSelection.Surname, IndividualSelection.Name, IndividualSelection.Patronymic, True);
			AreaHeader.Parameters.Ind = ?(ValueIsFilled(PresentationIndividual), PresentationIndividual, IndividualSelection.Ind);
			SpreadsheetDocument.Put(AreaHeader);
			SpreadsheetDocument.Put(HeaderArea);

			LastEarning = SpreadsheetDocument.TableHeight;
			LastDeduction = SpreadsheetDocument.TableHeight;
			
			SelectionDetails = IndividualSelection.Select();
			While SelectionDetails.Next() Do
			
				If SelectionDetails.Deduction = NULL Then
					
					If LastEarning < LastDeduction Then
						
						SpreadsheetDocument.Area(LastEarning + 1, 1).Text = SelectionDetails.Earning;
						SpreadsheetDocument.Area(LastEarning + 1, 2, LastEarning + 1, 3).Text = "" + Day(SelectionDetails.StartDate) + "-" + Day(SelectionDetails.EndDate) + " " + Format(SelectionDetails.EndDate , "DF=MMM");
						SpreadsheetDocument.Area(LastEarning + 1, 4).Text = SelectionDetails.DaysWorked;
						SpreadsheetDocument.Area(LastEarning + 1, 5).Text = SelectionDetails.HoursWorked;
						SpreadsheetDocument.Area(LastEarning + 1, 6, LastEarning + 1, 7).Text = SelectionDetails.AmountAccrued;
					
					Else
					
						AreaDetails.Parameters.Earning = SelectionDetails.Earning;
						AreaDetails.Parameters.PeriodEarning = "" + Day(SelectionDetails.StartDate) + "-" + Day(SelectionDetails.EndDate) + " " + Format(SelectionDetails.EndDate , "DF=MMM");
						AreaDetails.Parameters.DaysWorkedEarning = SelectionDetails.DaysWorked;
						AreaDetails.Parameters.HoursWorkedEarning = SelectionDetails.HoursWorked;
						AreaDetails.Parameters.AmountEarning = SelectionDetails.AmountAccrued;
						
						SpreadsheetDocument.Put(AreaDetails);
						
						AreaDetails.Parameters.Earning = Catalogs.EarningAndDeductionTypes.EmptyRef();
						AreaDetails.Parameters.PeriodEarning = "";
						AreaDetails.Parameters.DaysWorkedEarning = 0;
						AreaDetails.Parameters.HoursWorkedEarning = 0;
						AreaDetails.Parameters.AmountEarning = 0;
					
					EndIf; 
					
					LastEarning = LastEarning + 1;
				
				Else
					
					If LastDeduction < LastEarning Then
					
						SpreadsheetDocument.Area(LastDeduction + 1, 8, LastDeduction + 1, 10).Text = SelectionDetails.Deduction;	
						SpreadsheetDocument.Area(LastDeduction + 1, 11, LastDeduction + 1, 12).Text = "" + Day(SelectionDetails.StartDate) + "-" + Day(SelectionDetails.EndDate) + " " + Format(SelectionDetails.EndDate , "DF=MMM");
						SpreadsheetDocument.Area(LastDeduction + 1, 13, LastDeduction + 1, 14).Text = SelectionDetails.AmountWithheld;
					
					Else
					
						AreaDetails.Parameters.Deduction = SelectionDetails.Deduction;
						AreaDetails.Parameters.DeductionPeriod = "" + Day(SelectionDetails.StartDate) + "-" + Day(SelectionDetails.EndDate) + " " + Format(SelectionDetails.EndDate , "DF=MMM");
						AreaDetails.Parameters.AmountDeduction = SelectionDetails.AmountWithheld;
						
						SpreadsheetDocument.Put(AreaDetails);
						
						AreaDetails.Parameters.Deduction = Catalogs.EarningAndDeductionTypes.EmptyRef();
						AreaDetails.Parameters.DeductionPeriod = "";
						AreaDetails.Parameters.AmountDeduction = 0;
					
					EndIf; 
					
					LastDeduction = LastDeduction + 1;
				
				EndIf; 
		
			EndDo;

			AreaTotal.Parameters.TotalEarning = IndividualSelection.AmountAccrued;
			AreaTotal.Parameters.TotalDeductions = IndividualSelection.AmountWithheld;
			SpreadsheetDocument.Put(AreaTotal);
			
			SpreadsheetDocument.Put(AreaIncomePayed);
			EmployeePaymentsSelection		= QueryResult[1].Select();
			
			StructureSearchBySelection	= New Structure("Employee", IndividualSelection.Ind);
			While EmployeePaymentsSelection.FIndNext(StructureSearchBySelection) Do
				
				AreaPaymentDetails.Parameters.Fill(EmployeePaymentsSelection);
				AreaPaymentDetails.Parameters.PaymentText = ""
					+ EmployeePaymentsSelection.DocumentPresentation
					+ ?(EmployeePaymentsSelection.AdvanceFlag, "(advance)", "") + " #"
					+ TrimAll(EmployeePaymentsSelection.Number)
					+ " " + "dated" + " "
					+ Format(EmployeePaymentsSelection.Date, "DLF=D");
					
				AreaPaymentDetails.Parameters.PaymentsPeriod = ""
					+ Day(RegistrationPeriod)
					+ "-"
					+ Day(EndOfMonth(RegistrationPeriod))
					+ " "
					+ Format(EndOfMonth(RegistrationPeriod) , "DF=MMM");
				
				SpreadsheetDocument.Put(AreaPaymentDetails);
				
			EndDo;
			
			FooterArea.Parameters.AmountDebtOnBeginOfPeriod = IndividualSelection.BalanceAtBegin;
			FooterArea.Parameters.AmountDebtAtEndOfPeriod = IndividualSelection.ClosingBalance;
			If IndividualSelection.BalanceAtBegin < 0 Then
				FooterArea.Parameters.TextByBeginOfDebtPeriod = Nstr("en = 'Employee''s debt on month start:'; ru = 'Долг сотрудника на начало месяца:';pl = 'Zobowiązanie pracownika na początku miesiąca:';es_ES = 'Deuda del empleado para el inicio del mes:';es_CO = 'Deuda del empleado para el inicio del mes:';tr = 'Ayın başlangıcında çalışanın borcu:';it = 'Debito del dipendente all''inizio del mese:';de = 'Die Schulden des Mitarbeiters zum Monatsanfang:'");
			Else	
				FooterArea.Parameters.TextByBeginOfDebtPeriod = Nstr("en = 'Company''s debt on month start:'; ru = 'Долг компании на начало месяца:';pl = 'Zobowiązanie firmy na początku miesiąca:';es_ES = 'Deuda de la empresa para el inicio del mes:';es_CO = 'Deuda de la empresa para el inicio del mes:';tr = 'Ayın başlangıcında iş yerinin borcu:';it = 'Debito dell''azienda all''inizio del mese';de = 'Die Schulden der Firma zu Monatsbeginn:'");
			EndIf; 
			If IndividualSelection.ClosingBalance < 0 Then
				FooterArea.Parameters.TextAtEndOfPeriodOfDebt = Nstr("en = 'Employee''s debt on month end:'; ru = 'Долго сотрудника на конец месяца:';pl = 'Zobowiązanie pracownika na koniec miesiąca:';es_ES = 'Deuda del empleado para el final del mes:';es_CO = 'Deuda del empleado para el final del mes:';tr = 'Ayın sonunda çalışanın borcu:';it = 'Debito del dipendente alla fine del mese:';de = 'Schulden des Mitarbeiters am Monatsende:'");
			Else	
				FooterArea.Parameters.TextAtEndOfPeriodOfDebt = Nstr("en = 'Company''s debt on month end:'; ru = 'Долг компании на конец месяца:';pl = 'Zadłużenie firmy na koniec miesiąca:';es_ES = 'Deuda de la empresa para el final del mes:';es_CO = 'Deuda de la empresa para el final del mes:';tr = 'Ayın sonunda iş yerinin borcu:';it = 'Debito dell''azienda alla fine del mese:';de = 'Die Schulden der Firma am Monatsende:'");
			EndIf; 
			SpreadsheetDocument.Put(FooterArea);
			
		EndDo;

        SpreadsheetDocument.EndRowGroup();
	EndDo;	

EndProcedure

&AtClient
// Procedure - command handler Generate.
//
Procedure Generate(Command)
	
	MakeExecute();
	
EndProcedure

 
#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer form event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	RegistrationPeriod				= BegOfMonth(CurrentSessionDate());
	RegistrationPeriodPresentation	= Format(RegistrationPeriod, "DF='MMMM yyyy'");
	
	If Constants.UseSeveralCompanies.Get() Then
		Company = DriveReUse.GetValueByDefaultUser(Users.AuthorizedUser(), "MainCompany");
	EndIf;
	
	If Not ValueIsFilled(Company)Then
		Company = Catalogs.Companies.MainCompany;
	EndIf;
	
	Currency = DriveServer.GetPresentationCurrency(Company);
	
	If Not Constants.UseSeveralDepartments.Get() Then
		
		Department = Catalogs.BusinessUnits.MainDepartment;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - form event handler ChoiceProcessing
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ChoiceSource) = Type("ClientApplicationForm")
		AND Find(ChoiceSource.FormName, "Calendar") > 0 Then
		
		RegistrationPeriod = EndOfDay(ValueSelected);
		DriveClient.OnChangeRegistrationPeriod(ThisForm);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureHandlersOfTheFormAttributes

&AtClient
// Procedure - event handler Management of attribute RegistrationPeriod.
//
Procedure RegistrationPeriodTuning(Item, Direction, StandardProcessing)
	
	DriveClient.OnRegistrationPeriodRegulation(ThisForm, Direction);
	DriveClient.OnChangeRegistrationPeriod(ThisForm);
	
EndProcedure

&AtClient
// Procedure - event handler StartChoice of attribute RegistrationPeriod.
//
Procedure RegistrationPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing	 = False;
	
	CalendarDateOnOpen = ?(ValueIsFilled(RegistrationPeriod), RegistrationPeriod, DriveReUse.GetSessionCurrentDate());
	
	OpenForm("CommonForm.Calendar", DriveClient.GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen), ThisForm);
	
EndProcedure

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	
	ReportsOptions.OnSaveUserSettingsAtServer(ThisObject, Settings);
	
EndProcedure

#EndRegion
