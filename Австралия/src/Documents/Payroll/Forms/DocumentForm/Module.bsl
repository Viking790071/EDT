#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ColorTextLeaveEmpty = StyleColors.TextLeaveEmpty;
	
	//EarningsDeductionsSize
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.EarningsDeductions.Size");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= 0;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = 'Size'; ru = 'Размер';pl = 'Rozmiar';es_ES = 'Tamaño';es_CO = 'Tamaño';tr = 'Boyut';it = 'Dimensione';de = 'Größe'"));
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorTextLeaveEmpty);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("EarningsDeductionsSize");
	FieldAppearance.Use = True;
	
	//EarningsDeductionsDaysWorked
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.EarningsDeductions.DaysWorked");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= 0;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = 'Days'; ru = 'Дней';pl = 'Dni';es_ES = 'Días';es_CO = 'Días';tr = 'günler';it = 'Giorni';de = 'Tage'"));
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorTextLeaveEmpty);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("EarningsDeductionsDaysWorked");
	FieldAppearance.Use = True;
	
	//EarningsDeductionsHoursWorked
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.EarningsDeductions.HoursWorked");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= 0;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = 'Hours'; ru = 'Часов';pl = 'Godziny';es_ES = 'Horas';es_CO = 'Horas';tr = 'Saat';it = 'Ore';de = 'Stunden'"));
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorTextLeaveEmpty);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("EarningsDeductionsHoursWorked");
	FieldAppearance.Use = True;
	
	IncomeAndExpenseItemsInDocuments.SetConditionalAppearance(ThisObject, "EarningsDeductions");
	
EndProcedure

&AtServer
// Procedure fills the data structure for the GL account selection.
//
Procedure ReceiveDataForSelectAccountsSettlements(DataStructure)
	
	GLAccountsAvailableTypes = New Array;
	EarningAndDeductionType = DataStructure.EarningAndDeductionType;
	If Not ValueIsFilled(EarningAndDeductionType) Then
		
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.WorkInProgress);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.IndirectExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.Expenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherFixedAssets);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherIncome);
		
	ElsIf EarningAndDeductionType.Type = Enums.EarningAndDeductionTypes.Earning Then
		
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.WorkInProgress);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.IndirectExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.Expenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherFixedAssets);
		
	ElsIf EarningAndDeductionType.Type = Enums.EarningAndDeductionTypes.Deduction Then
		
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherIncome);
		
	EndIf;
	
	DataStructure.Insert("GLAccountsAvailableTypes", GLAccountsAvailableTypes);
	
EndProcedure

// The procedure fills in the indicator table by parameters.
//
&AtServer
Procedure FillIndicators(ReturnStructure)

	EarningAndDeductionType = ReturnStructure.EarningAndDeductionType;	
	ReturnStructure.Insert("Indicator1", "");
	ReturnStructure.Insert("Presentation1", Catalogs.EarningsCalculationParameters.EmptyRef());
	ReturnStructure.Insert("Value1", 0);
	ReturnStructure.Insert("Indicator2", "");
	ReturnStructure.Insert("Presentation2", Catalogs.EarningsCalculationParameters.EmptyRef());
	ReturnStructure.Insert("Value2", 0);
	ReturnStructure.Insert("Indicator3", "");
	ReturnStructure.Insert("Presentation3", Catalogs.EarningsCalculationParameters.EmptyRef());
	ReturnStructure.Insert("Value3", 0);
	
	// 1. Checking
	If Not ValueIsFilled(EarningAndDeductionType) Then
		Return;
	EndIf; 
	
	// 2. Search of all parameters-identifiers for the formula
	ParametersStructure = New Structure;
	DriveServer.AddParametersToStructure(EarningAndDeductionType.Formula, ParametersStructure);
		
	// 3. Adding the indicator
	Counter = 0;
	For Each ParameterStructures In ParametersStructure Do
		
		If ParameterStructures.Key = "DaysWorked" 
			OR ParameterStructures.Key = "HoursWorked"
			OR ParameterStructures.Key = "TariffRate" Then
			
			Continue;
			
		EndIf; 
		
		CalculationParameter = Catalogs.EarningsCalculationParameters.FindByAttribute("ID", ParameterStructures.Key);
		If Not ValueIsFilled(CalculationParameter) Then
			
			CommonClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Parameter %1 is not found for formula %2'; ru = 'Не найден параметр %1 для формулы %2';pl = 'Nie znaleziono parametru %1 dla formuły %2';es_ES = 'Parámetro %1 no se ha encontrado para la fórmula %2';es_CO = 'Parámetro %1 no se ha encontrado para la fórmula %2';tr = '%1Parametre %2 formülde bulunamadı';it = 'Parametro %1 non è stato trovato per la formula %2';de = 'Parameter %1 wurde für Formel %2 nicht gefunden'"),
				CalculationParameter,
				EarningAndDeductionType));
				
			Continue;
			
		EndIf; 
		
		Counter = Counter + 1;
		
		If Counter > 3 Then
			
			Break;
			
		EndIf; 
		
		ReturnStructure["Indicator" + Counter] = ParameterStructures.Key;
		ReturnStructure["Presentation" + Counter] = CalculationParameter;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillIncomeAndExpenses(DataStructure)
	
	IncomeAndExpensesData = Common.ObjectAttributesValues(DataStructure.EarningAndDeductionType, "Type, IncomeAndExpenseItem");
	
	DataStructure.ExpenseItem = ?(
		IncomeAndExpensesData.Type = Enums.EarningAndDeductionTypes.Earning, 
		IncomeAndExpensesData.IncomeAndExpenseItem, 
		Catalogs.IncomeAndExpenseItems.EmptyRef());
		
	DataStructure.IncomeItem = ?(
		IncomeAndExpensesData.Type = Enums.EarningAndDeductionTypes.Deduction, 
		IncomeAndExpensesData.IncomeAndExpenseItem, 
		Catalogs.IncomeAndExpenseItems.EmptyRef());
		
	DataStructure.RegisterExpense = (IncomeAndExpensesData.Type = Enums.EarningAndDeductionTypes.Earning);
	DataStructure.RegisterIncome = (IncomeAndExpensesData.Type = Enums.EarningAndDeductionTypes.Deduction);
	
	DataStructure = IncomeAndExpenseItemsInDocumentsServerCall.GetIncomeAndExpenseItemsDescription(DataStructure);
	
EndProcedure

&AtServer
Procedure GetGLAccountByDefault(DataStructure)
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	CompensationPlanSliceLast.GLExpenseAccount AS GLExpenseAccount,
		|	CompensationPlanSliceLast.GLExpenseAccount.TypeOfAccount AS TypeOfAccount
		|FROM
		|	InformationRegister.CompensationPlan.SliceLast(
		|			&Period,
		|			Company = &Company
		|				AND Employee = &Employee
		|				AND EarningAndDeductionType = &EarningAndDeductionType
		|				AND Currency = &Currency) AS CompensationPlanSliceLast";
	
	Query.SetParameter("EarningAndDeductionType",	DataStructure.EarningAndDeductionType);
	Query.SetParameter("Company",				Object.Company);
	Query.SetParameter("Currency",				Object.DocumentCurrency);
	Query.SetParameter("Employee",				DataStructure.Employee);
	Query.SetParameter("Period",				DataStructure.StartDate);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	If Selection.Next() Then 
		FillPropertyValues(DataStructure, Selection, "GLExpenseAccount, TypeOfAccount"); 
	Else
		If ValueIsFilled(DataStructure.EarningAndDeductionType) Then
			DataStructure.Insert("StructuralUnit",	Object.StructuralUnit);
			DriveServer.GetEarningKindGLExpenseAccount(DataStructure);
		EndIf;
	EndIf;
	
	FillAddedColumns();
	
EndProcedure

&AtServer
// The function creates the table of Earnings.
//
Function GenerateEarningsTable()

	TableEarnings = New ValueTable;

	Array = New Array;
	
	Array.Add(Type("CatalogRef.Employees"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	TableEarnings.Columns.Add("Employee", TypeDescription);

	Array.Add(Type("CatalogRef.Positions"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	TableEarnings.Columns.Add("Position", TypeDescription);
	
	Array.Add(Type("CatalogRef.EarningAndDeductionTypes"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	TableEarnings.Columns.Add("EarningAndDeductionType", TypeDescription);

	Array.Add(Type("Date"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	TableEarnings.Columns.Add("StartDate", TypeDescription);
	
	Array.Add(Type("Date"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	TableEarnings.Columns.Add("EndDate", TypeDescription);
	
	Array.Add(Type("ChartOfAccountsRef.PrimaryChartOfAccounts"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	TableEarnings.Columns.Add("GLExpenseAccount", TypeDescription);

	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	TableEarnings.Columns.Add("Size", TypeDescription);

	Array.Add(Type("CatalogRef.IncomeAndExpenseItems"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	TableEarnings.Columns.Add("ExpenseItem", TypeDescription);
	TableEarnings.Columns.Add("IncomeItem", TypeDescription);
	
	Array.Add(Type("Boolean"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	TableEarnings.Columns.Add("RegisterExpense", TypeDescription);
	TableEarnings.Columns.Add("RegisterIncome", TypeDescription);
	
	For Each TSRow In Object.EarningsDeductions Do
		
		NewRow = TableEarnings.Add();
		NewRow.Employee = TSRow.Employee;
		NewRow.Position = TSRow.Position;
		NewRow.EarningAndDeductionType = TSRow.EarningAndDeductionType;
		NewRow.StartDate = TSRow.StartDate;
		NewRow.EndDate = TSRow.EndDate;
		NewRow.GLExpenseAccount = TSRow.GLExpenseAccount;
		NewRow.Size = TSRow.Size;
		NewRow.ExpenseItem = TSRow.ExpenseItem;
		NewRow.RegisterExpense = TSRow.RegisterExpense;
		NewRow.IncomeItem = TSRow.IncomeItem;
		NewRow.RegisterIncome = TSRow.RegisterIncome;
		
	EndDo;
	
	Return TableEarnings;
	
EndFunction

&AtServer
// The procedure fills in the Employees tabular section with filter by department.
//
Procedure FillByDepartment()

	Object.EarningsDeductions.Clear();
	Object.IncomeTaxes.Clear();
	
	Query = New Query;
	
	Query.Parameters.Insert("BegOfMonth", 		Object.RegistrationPeriod);
	Query.Parameters.Insert("EndOfMonth",	EndOfMonth(Object.RegistrationPeriod));
	Query.Parameters.Insert("Company", 		DriveServer.GetCompany(Object.Company));
	Query.Parameters.Insert("StructuralUnit", Object.StructuralUnit);
	Query.Parameters.Insert("Currency", 			Object.DocumentCurrency);
		
	// 1. Define the	employees we need
	// 2. Define all records of the employees we need, and Earnings in the corresponding department.
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	NestedSelect.Employee AS Employee
	|INTO EmployeesDeparnments
	|FROM
	|	(SELECT
	|		EmployeesSliceLast.Employee AS Employee
	|	FROM
	|		InformationRegister.Employees.SliceLast(&BegOfMonth, Company = &Company) AS EmployeesSliceLast
	|	WHERE
	|		EmployeesSliceLast.StructuralUnit = &StructuralUnit
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Employees.Employee
	|	FROM
	|		InformationRegister.Employees AS Employees
	|	WHERE
	|		Employees.StructuralUnit = &StructuralUnit
	|		AND Employees.Period between &BegOfMonth AND &EndOfMonth
	|		AND Employees.Company = &Company) AS NestedSelect
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	NestedSelect.Employee AS Employee,
	|	NestedSelect.StructuralUnit AS StructuralUnit,
	|	NestedSelect.Position AS Position,
	|	CompensationPlan.EarningAndDeductionType AS EarningAndDeductionType,
	|	CompensationPlan.Amount AS Amount,
	|	CASE
	|		WHEN CompensationPlan.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN CompensationPlan.IncomeAndExpenseItem
	|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	END AS ExpenseItem,
	|	CASE
	|		WHEN CompensationPlan.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|			THEN CompensationPlan.IncomeAndExpenseItem
	|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	END AS IncomeItem,
	|	CompensationPlan.GLExpenseAccount AS GLExpenseAccount,
	|	CompensationPlan.Actuality AS Actuality,
	|	NestedSelect.Period AS Period,
	|	NestedSelect.OthersUnitTerminationOfEmployment AS OthersUnitTerminationOfEmployment
	|INTO EmployeeRecords
	|FROM
	|	(SELECT
	|		EmployeesDeparnments.Employee AS Employee,
	|		Employees.StructuralUnit AS StructuralUnit,
	|		Employees.Position AS Position,
	|		MAX(CompensationPlan.Period) AS EarningPeriod,
	|		Employees.Period AS Period,
	|		CASE
	|			WHEN Employees.StructuralUnit = &StructuralUnit
	|				THEN FALSE
	|			ELSE TRUE
	|		END AS OthersUnitTerminationOfEmployment,
	|		CompensationPlan.EarningAndDeductionType AS EarningAndDeductionType,
	|		CompensationPlan.Currency AS Currency
	|	FROM
	|		EmployeesDeparnments AS EmployeesDeparnments
	|			INNER JOIN InformationRegister.Employees AS Employees
	|				LEFT JOIN InformationRegister.CompensationPlan AS CompensationPlan
	|				ON Employees.Company = CompensationPlan.Company
	|					AND Employees.Employee = CompensationPlan.Employee
	|					AND Employees.Period >= CompensationPlan.Period
	|					AND (Employees.StructuralUnit = &StructuralUnit)
	|					AND (CompensationPlan.Currency = &Currency)
	|					AND (CompensationPlan.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePay))
	|					AND (CompensationPlan.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayPercent))
	|					AND (CompensationPlan.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayFixedAmount))
	|			ON EmployeesDeparnments.Employee = Employees.Employee
	|	WHERE
	|		Employees.Company = &Company
	|		AND Employees.Period between DATEADD(&BegOfMonth, Day, 1) AND &EndOfMonth
	|	
	|	GROUP BY
	|		Employees.StructuralUnit,
	|		EmployeesDeparnments.Employee,
	|		Employees.Position,
	|		Employees.Period,
	|		CompensationPlan.EarningAndDeductionType,
	|		CompensationPlan.Currency,
	|		CASE
	|			WHEN Employees.StructuralUnit = &StructuralUnit
	|				THEN FALSE
	|			ELSE TRUE
	|		END) AS NestedSelect
	|		LEFT JOIN InformationRegister.CompensationPlan AS CompensationPlan
	|		ON NestedSelect.Employee = CompensationPlan.Employee
	|			AND (CompensationPlan.Currency = &Currency)
	|			AND (CompensationPlan.Company = &Company)
	|			AND NestedSelect.EarningPeriod = CompensationPlan.Period
	|			AND NestedSelect.EarningAndDeductionType = CompensationPlan.EarningAndDeductionType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	NestedSelect.Employee,
	|	NestedSelect.Period,
	|	NestedSelect.EarningAndDeductionType,
	|	NestedSelect.Amount,
	|	NestedSelect.ExpenseItem,
	|	NestedSelect.IncomeItem,
	|	NestedSelect.GLExpenseAccount,
	|	NestedSelect.Actuality,
	|	Employees.StructuralUnit,
	|	Employees.Position
	|INTO RegisterRecordsPlannedEarning
	|FROM
	|	(SELECT
	|		CompensationPlan.Employee AS Employee,
	|		CompensationPlan.Period AS Period,
	|		CompensationPlan.EarningAndDeductionType AS EarningAndDeductionType,
	|		CompensationPlan.Amount AS Amount,
	|		CASE
	|			WHEN CompensationPlan.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|				THEN CASE
	|						WHEN CompensationPlan.IncomeAndExpenseItem = VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|							THEN CompensationPlan.EarningAndDeductionType.IncomeAndExpenseItem
	|						ELSE CompensationPlan.IncomeAndExpenseItem
	|					END
	|			ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|		END AS ExpenseItem,
	|		CASE
	|			WHEN CompensationPlan.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|				THEN CompensationPlan.IncomeAndExpenseItem
	|			ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|		END AS IncomeItem,
	|		CASE
	|			WHEN CompensationPlan.GLExpenseAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|				THEN CompensationPlan.EarningAndDeductionType.GLExpenseAccount
	|			ELSE CompensationPlan.GLExpenseAccount
	|		END AS GLExpenseAccount,
	|		CompensationPlan.Actuality AS Actuality,
	|		MAX(Employees.Period) AS PeriodStaff
	|	FROM
	|		EmployeesDeparnments AS EmployeesDeparnments
	|			INNER JOIN InformationRegister.CompensationPlan AS CompensationPlan
	|				LEFT JOIN InformationRegister.Employees AS Employees
	|				ON CompensationPlan.Employee = Employees.Employee
	|					AND CompensationPlan.Period >= Employees.Period
	|					AND (Employees.Company = &Company)
	|			ON EmployeesDeparnments.Employee = CompensationPlan.Employee
	|				AND (CompensationPlan.Currency = &Currency)
	|				AND (CompensationPlan.Period between DATEADD(&BegOfMonth, Day, 1) AND &EndOfMonth)
	|				AND (CompensationPlan.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePay))
	|				AND (CompensationPlan.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayPercent))
	|				AND (CompensationPlan.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayFixedAmount))
	|				AND (CompensationPlan.Company = &Company)
	|	
	|	GROUP BY
	|		CompensationPlan.Actuality,
	|		CASE
	|			WHEN CompensationPlan.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|				THEN CASE
	|						WHEN CompensationPlan.IncomeAndExpenseItem = VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|							THEN CompensationPlan.EarningAndDeductionType.IncomeAndExpenseItem
	|						ELSE CompensationPlan.IncomeAndExpenseItem
	|					END
	|			ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|		END,
	|		CASE
	|			WHEN CompensationPlan.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|				THEN CompensationPlan.IncomeAndExpenseItem
	|			ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|		END,
	|		CASE
	|			WHEN CompensationPlan.GLExpenseAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|				THEN CompensationPlan.EarningAndDeductionType.GLExpenseAccount
	|			ELSE CompensationPlan.GLExpenseAccount
	|		END,
	|		CompensationPlan.Period,
	|		CompensationPlan.EarningAndDeductionType,
	|		CompensationPlan.Employee,
	|		CompensationPlan.Amount) AS NestedSelect
	|		LEFT JOIN InformationRegister.Employees AS Employees
	|		ON NestedSelect.PeriodStaff = Employees.Period
	|			AND (Employees.Company = &Company)
	|			AND NestedSelect.Employee = Employees.Employee
	|WHERE
	|	Employees.StructuralUnit = &StructuralUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	NestedSelect.Employee AS Employee,
	|	NestedSelect.StructuralUnit AS StructuralUnit,
	|	NestedSelect.Position AS Position,
	|	NestedSelect.DateActionsBegin AS DateActionsBegin,
	|	NestedSelect.EarningAndDeductionType AS EarningAndDeductionType,
	|	NestedSelect.Size AS Size,
	|	NestedSelect.ExpenseItem,
	|	NestedSelect.IncomeItem,
	|	NestedSelect.GLExpenseAccount AS GLExpenseAccount,
	|	NestedSelect.Actuality,
	|	CASE
	|		WHEN NestedSelect.StructuralUnit = &StructuralUnit
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS OtherUnitTerminationOfEmployment,
	|	CASE
	|		WHEN NestedSelect.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS IsTax
	|FROM
	|	(SELECT
	|		EmployeesDeparnments.Employee AS Employee,
	|		EmployeesSliceLast.StructuralUnit AS StructuralUnit,
	|		EmployeesSliceLast.Position AS Position,
	|		&BegOfMonth AS DateActionsBegin,
	|		CompensationPlanSliceLast.EarningAndDeductionType AS EarningAndDeductionType,
	|		CompensationPlanSliceLast.Amount AS Size,
	|		CASE
	|			WHEN CompensationPlanSliceLast.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|				THEN CASE
	|						WHEN CompensationPlanSliceLast.IncomeAndExpenseItem = VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|							THEN CompensationPlanSliceLast.EarningAndDeductionType.IncomeAndExpenseItem
	|						ELSE CompensationPlanSliceLast.IncomeAndExpenseItem
	|					END
	|			ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|		END AS ExpenseItem,
	|		CASE
	|			WHEN CompensationPlanSliceLast.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|				THEN CompensationPlanSliceLast.IncomeAndExpenseItem
	|			ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|		END AS IncomeItem,
	|		CASE
	|			WHEN CompensationPlanSliceLast.GLExpenseAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|				THEN CompensationPlanSliceLast.EarningAndDeductionType.GLExpenseAccount
	|			ELSE CompensationPlanSliceLast.GLExpenseAccount
	|		END AS GLExpenseAccount,
	|		TRUE AS Actuality
	|	FROM
	|		EmployeesDeparnments AS EmployeesDeparnments
	|			INNER JOIN InformationRegister.Employees.SliceLast(&BegOfMonth, Company = &Company) AS EmployeesSliceLast
	|			ON EmployeesDeparnments.Employee = EmployeesSliceLast.Employee
	|			INNER JOIN InformationRegister.CompensationPlan.SliceLast(
	|					&BegOfMonth,
	|					Company = &Company
	|						AND Currency = &Currency) AS CompensationPlanSliceLast
	|			ON EmployeesDeparnments.Employee = CompensationPlanSliceLast.Employee
	|	WHERE
	|		CompensationPlanSliceLast.Actuality
	|		AND CompensationPlanSliceLast.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePay)
	|		AND CompensationPlanSliceLast.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayPercent)
	|		AND CompensationPlanSliceLast.EarningAndDeductionType <> VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayFixedAmount)
	|		AND EmployeesSliceLast.StructuralUnit = &StructuralUnit
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CompensationPlan.Employee
	|			ELSE Employees.Employee
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CompensationPlan.StructuralUnit
	|			ELSE Employees.StructuralUnit
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CompensationPlan.Position
	|			ELSE Employees.Position
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CompensationPlan.Period
	|			ELSE Employees.Period
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CompensationPlan.EarningAndDeductionType
	|			ELSE Employees.EarningAndDeductionType
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CompensationPlan.Amount
	|			ELSE Employees.Amount
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL
	|				THEN CASE
	|						WHEN CompensationPlan.EarningAndDeductionType.Type <> VALUE(Enum.EarningAndDeductionTypes.Earning)
	|								THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|						WHEN CompensationPlan.ExpenseItem = VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|							THEN CompensationPlan.EarningAndDeductionType.IncomeAndExpenseItem
	|						ELSE CompensationPlan.ExpenseItem
	|					END
	|			ELSE CASE
	|					WHEN Employees.EarningAndDeductionType.Type <> VALUE(Enum.EarningAndDeductionTypes.Earning)
	|						THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|					WHEN Employees.ExpenseItem = VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|						THEN Employees.EarningAndDeductionType.IncomeAndExpenseItem
	|					ELSE Employees.ExpenseItem
	|				END
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL
	|				THEN CASE
	|						WHEN CompensationPlan.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|							THEN CompensationPlan.IncomeItem
	|						ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|					END
	|			ELSE CASE
	|					WHEN Employees.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|						THEN Employees.IncomeItem
	|					ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|				END
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CASE
	|						WHEN CompensationPlan.GLExpenseAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|							THEN CompensationPlan.EarningAndDeductionType.GLExpenseAccount
	|						ELSE CompensationPlan.GLExpenseAccount
	|					END
	|			ELSE CASE
	|					WHEN Employees.GLExpenseAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|						THEN Employees.EarningAndDeductionType.GLExpenseAccount
	|					ELSE Employees.GLExpenseAccount
	|				END
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CompensationPlan.Actuality
	|			ELSE Employees.Actuality
	|		END
	|	FROM
	|		EmployeeRecords AS Employees
	|			FULL JOIN RegisterRecordsPlannedEarning AS CompensationPlan
	|			ON Employees.Employee = CompensationPlan.Employee
	|				AND Employees.Period = CompensationPlan.Period
	|				AND Employees.EarningAndDeductionType = CompensationPlan.EarningAndDeductionType) AS NestedSelect
	|
	|ORDER BY
	|	Employee,
	|	DateActionsBegin
	|TOTALS BY
	|	Employee";
	
	ResultsArray = Query.ExecuteBatch();
	
	// 3. We define the period end dates and fill in the value table.
	
	EndOfMonth = BegOfDay(EndOfMonth(Object.RegistrationPeriod));
	SelectionEmployee = ResultsArray[3].Select(QueryResultIteration.ByGroups, "Employee");
	While SelectionEmployee.Next() Do
		
		Selection = SelectionEmployee.Select();
		
		While Selection.Next() Do
			
			If Selection.OtherUnitTerminationOfEmployment Then
				ReplaceDateArray = Object.EarningsDeductions.FindRows(New Structure("EndDate, Employee", EndOfMonth, Selection.Employee));
				For Each ArrayElement In ReplaceDateArray Do
					ArrayElement.EndDate = Selection.DateActionsBegin - 60*60*24;
				EndDo;
				Continue;
			EndIf; 
			
			ReplaceDateArray = Object.EarningsDeductions.FindRows(New Structure("EndDate, Employee, EarningAndDeductionType", EndOfMonth, Selection.Employee, Selection.EarningAndDeductionType));
			For Each ArrayElement In ReplaceDateArray Do
				ArrayElement.EndDate = Selection.DateActionsBegin - 60*60*24;
			EndDo;
			
			If ValueIsFilled(Selection.EarningAndDeductionType) AND Selection.Actuality Then
			
				If Selection.IsTax Then				
										
					NewRow							= Object.IncomeTaxes.Add();
					NewRow.Employee 				= Selection.Employee;
					NewRow.EarningAndDeductionType 	= Selection.EarningAndDeductionType;
				
				Else
				
					NewRow							= Object.EarningsDeductions.Add();
					NewRow.Employee 				= Selection.Employee;
					NewRow.Position 				= Selection.Position;
					NewRow.EarningAndDeductionType 	= Selection.EarningAndDeductionType;
					NewRow.StartDate 				= Selection.DateActionsBegin;
					NewRow.EndDate 					= EndOfMonth;
					NewRow.Size 					= Selection.Size;
					
					EarningAndDeductionType = TypeOfEarningAndDeductionType(NewRow.EarningAndDeductionType);
					RegisterExpense = EarningAndDeductionType = Enums.EarningAndDeductionTypes.Earning;
					RegisterIncome = EarningAndDeductionType = Enums.EarningAndDeductionTypes.Deduction;
					
					If UseDefaultTypeOfAccounting Then
						
						TypeOfAccount = Selection.GLExpenseAccount.TypeOfAccount;
						If Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Department
							And Not (TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
							Or TypeOfAccount = Enums.GLAccountsTypes.Expenses
							Or TypeOfAccount = Enums.GLAccountsTypes.WorkInProgress
							Or TypeOfAccount = Enums.GLAccountsTypes.OtherCurrentAssets
							Or TypeOfAccount = Enums.GLAccountsTypes.AccountsPayable) Then
							
							NewRow.GLExpenseAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
							NewRow.ExpenseItem = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
							NewRow.IncomeItem = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
							
						Else
							NewRow.GLExpenseAccount = Selection.GLExpenseAccount;
							NewRow.ExpenseItem = Selection.ExpenseItem;
							NewRow.IncomeItem = Selection.IncomeItem;
						EndIf;
						
						RegisterExpenseIncome = IsIncomeAndExpenseGLA(NewRow.GLExpenseAccount);
						NewRow.RegisterExpense = RegisterExpenseIncome And RegisterExpense;
						NewRow.RegisterIncome = RegisterExpenseIncome And RegisterIncome;
						
					Else
						NewRow.ExpenseItem = Selection.ExpenseItem;
						NewRow.IncomeItem = Selection.IncomeItem;
						NewRow.RegisterExpense = RegisterExpense;
						NewRow.RegisterIncome = False;
					EndIf;
					
				EndIf;
				
			EndIf; 
					
		EndDo;
		
	EndDo;
	
	// 4. Fill in working hours
		
	Query.Parameters.Insert("TableEarningsDeductions", GenerateEarningsTable());
	
	Query.Text =
	"SELECT
	|	TableEarningsDeductions.Employee,
	|	TableEarningsDeductions.Position,
	|	TableEarningsDeductions.EarningAndDeductionType,
	|	TableEarningsDeductions.StartDate,
	|	TableEarningsDeductions.EndDate,
	|	TableEarningsDeductions.Size,
	|	TableEarningsDeductions.GLExpenseAccount,
	|	TableEarningsDeductions.ExpenseItem,
	|	TableEarningsDeductions.RegisterExpense,
	|	TableEarningsDeductions.IncomeItem,
	|	TableEarningsDeductions.RegisterIncome
	|INTO TableEarningsDeductions
	|FROM
	|	&TableEarningsDeductions AS TableEarningsDeductions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DocumentAssessment.Employee AS Employee,
	|	DocumentAssessment.Position AS Position,
	|	DocumentAssessment.EarningAndDeductionType AS EarningAndDeductionType,
	|	DocumentAssessment.StartDate AS StartDate,
	|	DocumentAssessment.EndDate AS EndDate,
	|	DocumentAssessment.Size AS Size,
	|	DocumentAssessment.GLExpenseAccount AS GLExpenseAccount,
	|	DocumentAssessment.ExpenseItem,
	|	DocumentAssessment.RegisterExpense,
	|	DocumentAssessment.IncomeItem,
	|	DocumentAssessment.RegisterIncome,
	|	ScheduleData.DaysWorked AS DaysWorked,
	|	ScheduleData.HoursWorked,
	|	ScheduleData.TotalForPeriod
	|FROM
	|	TableEarningsDeductions AS DocumentAssessment
	|		LEFT JOIN (SELECT
	|			DocumentAssessment.Employee AS Employee,
	|			SUM(Timesheet.Days) AS DaysWorked,
	|			SUM(Timesheet.Hours) AS HoursWorked,
	|			DocumentAssessment.StartDate AS StartDate,
	|			DocumentAssessment.EndDate AS EndDate,
	|			MAX(ISNULL(Timesheet.TotalForPeriod, FALSE)) AS TotalForPeriod
	|		FROM
	|			(SELECT DISTINCT
	|				DocumentAssessment.Employee AS Employee,
	|				DocumentAssessment.StartDate AS StartDate,
	|				DocumentAssessment.EndDate AS EndDate
	|			FROM
	|				TableEarningsDeductions AS DocumentAssessment) AS DocumentAssessment
	|				LEFT JOIN AccumulationRegister.Timesheet AS Timesheet
	|				ON DocumentAssessment.Employee = Timesheet.Employee
	|					AND (Timesheet.TimeKind = VALUE(Catalog.PayCodes.Work))
	|					AND (Timesheet.Company = &Company)
	|					AND (Timesheet.StructuralUnit = &StructuralUnit)
	|					AND ((NOT Timesheet.TotalForPeriod)
	|							AND DocumentAssessment.StartDate <= Timesheet.Period
	|							AND DocumentAssessment.EndDate >= Timesheet.Period
	|						OR Timesheet.TotalForPeriod
	|							AND Timesheet.Period = BEGINOFPERIOD(DocumentAssessment.StartDate, MONTH))
	|		
	|		GROUP BY
	|			DocumentAssessment.Employee,
	|			DocumentAssessment.StartDate,
	|			DocumentAssessment.EndDate) AS ScheduleData
	|		ON DocumentAssessment.Employee = ScheduleData.Employee
	|			AND DocumentAssessment.StartDate = ScheduleData.StartDate
	|			AND DocumentAssessment.EndDate = ScheduleData.EndDate";
	
	QueryResult = Query.ExecuteBatch()[1].Unload();
	Object.EarningsDeductions.Load(QueryResult); 
		
	Object.EarningsDeductions.Sort("Employee Asc, StartDate Asc, EarningAndDeductionType Asc");
	
	For Each TabularSectionRow In Object.EarningsDeductions Do
		
		// 1. Checking
		If Not ValueIsFilled(TabularSectionRow.EarningAndDeductionType) Then
			Continue;
		EndIf; 
		RepetitionsArray = QueryResult.FindRows(New Structure("Employee, EarningAndDeductionType", TabularSectionRow.Employee, TabularSectionRow.EarningAndDeductionType));
		If RepetitionsArray.Count() > 1 AND RepetitionsArray[0].TotalForPeriod Then
			
			TabularSectionRow.DaysWorked = 0;
			TabularSectionRow.HoursWorked = 0;
			
			MessageText = NStr("en = '%Employee%, %EarningKind%: Working hours data has been entered consolidated. Time calculation for each earning or deduction type is not possible.'; ru = '%Employee%, %EarningKind%: Данные об отработанном времени введены сводно. Расчет времени по каждому типу начисления (удержания) невозможен.';pl = '%Employee%, %EarningKind%: Dane odnośnie godzin pracy zostały wprowadzone jako skonsolidowane. Obliczanie czasu dla każdego rodzaju dochodu lub potrącenia nie jest możliwe.';es_ES = '%Employee%, %EarningKind%: Datos de las horas laborales se han introducido consolidados. Cálculo de tiempo para cada tipo de ingresos y deducciones no es posible.';es_CO = '%Employee%, %EarningKind%: Datos de las horas laborales se han introducido consolidados. Cálculo de tiempo para cada tipo de ingresos y deducciones no es posible.';tr = '%Employee%, %EarningKind%: Çalışma saatleri verileri konsolide edildi. Her kazanç veya indirim türü için zaman hesaplaması mümkün değildir.';it = '%Employee%, %EarningKind%: i dati delle ore di lavoro sono stati inseriti consolidati. Il tempo di calcolo per ogni tipo di compenso o trattenuta non è possibile.';de = '%Employee%, %EarningKind%: Die Arbeitszeitdaten wurden konsolidiert erfasst. Eine Zeitberechnung für jede Bezugs- oder Abzugsart ist nicht möglich.'");
			MessageText = StrReplace(MessageText, "%Employee%", TabularSectionRow.Employee);
			MessageText = StrReplace(MessageText, "%EarningKind%", TabularSectionRow.EarningAndDeductionType);
			MessageField = "Object.EarningsDeductions[" + Object.EarningsDeductions.IndexOf(TabularSectionRow) + "].Employee";
			
			DriveServer.ShowMessageAboutError(Object, MessageText,,,MessageField);
			
		EndIf;
		
		// 2. Clearing
		For Counter = 1 To 3 Do		
			TabularSectionRow["Indicator" + Counter] = "";
			TabularSectionRow["Presentation" + Counter] = Catalogs.EarningsCalculationParameters.EmptyRef();
			TabularSectionRow["Value" + Counter] = 0;	
		EndDo;
		
		// 3. Search of all parameters-identifiers for the formula
		ParametersStructure = New Structure;
		DriveServer.AddParametersToStructure(TabularSectionRow.EarningAndDeductionType.Formula, ParametersStructure);
		
		// 4. Adding the indicator
		Counter = 0;
		For Each ParameterStructures In ParametersStructure Do
			
			If ParameterStructures.Key = "DaysWorked"
					OR ParameterStructures.Key = "HoursWorked"
					OR ParameterStructures.Key = "TariffRate" Then
			    Continue;
			EndIf; 
						
			CalculationParameter = Catalogs.EarningsCalculationParameters.FindByAttribute("ID", ParameterStructures.Key);
		 	If Not ValueIsFilled(CalculationParameter) Then		
				Message = New UserMessage();
				Message.Text = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The %1 parameter is not found for the employee in row #%2.'; ru = 'Для сотрудника в строке %2 не найден параметр %1.';pl = 'Parametr %1 nie został znaleziony dla pracownika w wierszu nr #%2.';es_ES = 'El parámetro %1 no está encontrado para el empleado en fila #%2.';es_CO = 'El parámetro %1 no está encontrado para el empleado en fila #%2.';tr = '#%2 satırındaki çalışan için %1 parametresi bulunamadı.';it = 'Il parametro %1 non è stato trovato per il dipendente in riga #%2.';de = 'Der %1 Parameter wird für den Mitarbeiter in Zeile Nr %2 nicht gefunden.'"),
					CalculationParameter,
					(Object.EarningsDeductions.IndexOf(TabularSectionRow) + 1));
				Message.Message();
		    EndIf; 
			
			Counter = Counter + 1;
			
			If Counter > 3 Then
				Break;
			EndIf; 
			
			TabularSectionRow["Indicator" + Counter] = ParameterStructures.Key;
			TabularSectionRow["Presentation" + Counter] = CalculationParameter;
			
			If CalculationParameter.SpecifyValueAtPayrollCalculation Then
				Continue;
			EndIf; 
			
		// 5. Indicator calculation
			
			StructureOfSelections = New Structure;
			StructureOfSelections.Insert("RegistrationPeriod", 		Object.RegistrationPeriod);
			StructureOfSelections.Insert("Company", 			    DriveServer.GetCompany(Object.Company));
			StructureOfSelections.Insert("Currency", 				Object.DocumentCurrency);
			StructureOfSelections.Insert("Department", 		     	Object.StructuralUnit);
			StructureOfSelections.Insert("StructuralUnit", 	        Object.StructuralUnit);
			StructureOfSelections.Insert("PointInTime", 			EndOfDay(TabularSectionRow.EndDate));
			StructureOfSelections.Insert("BeginOfPeriod", 			TabularSectionRow.StartDate);
			StructureOfSelections.Insert("EndOfPeriod", 			EndOfDay(TabularSectionRow.EndDate));
			StructureOfSelections.Insert("Employee",		 		TabularSectionRow.Employee);
			StructureOfSelections.Insert("EmploymentContractType",	TabularSectionRow.Employee.EmploymentContractType);
			StructureOfSelections.Insert("EmployeeCode",		 	TabularSectionRow.Employee.Code);
			StructureOfSelections.Insert("TabNumber",		 		TabularSectionRow.Employee.Code);
			StructureOfSelections.Insert("Performer",		 	    TabularSectionRow.Employee);
			StructureOfSelections.Insert("Ind",		 		        TabularSectionRow.Employee.Ind);
			StructureOfSelections.Insert("Individual",		 	    TabularSectionRow.Employee.Ind);
			StructureOfSelections.Insert("Position", 				TabularSectionRow.Position);
			StructureOfSelections.Insert("EarningAndDeductionType", TabularSectionRow.EarningAndDeductionType);
			StructureOfSelections.Insert("SalesOrder", 		        TabularSectionRow.SalesOrder);
			StructureOfSelections.Insert("Order", 					TabularSectionRow.SalesOrder);
			
			If ValueIsFilled(TabularSectionRow.SalesOrder) Then
				SalesOrderProject = Common.ObjectAttributeValue(TabularSectionRow.SalesOrder, "Project");
			Else
				SalesOrderProject = Catalogs.Projects.EmptyRef();
			EndIf;
			
			StructureOfSelections.Insert("Project", 				SalesOrderProject);
			StructureOfSelections.Insert("GLExpenseAccount", 		TabularSectionRow.GLExpenseAccount);
			StructureOfSelections.Insert("BusinessLine",            TabularSectionRow.BusinessLine);
			StructureOfSelections.Insert("Size",					TabularSectionRow.Size);
			StructureOfSelections.Insert("DaysWorked",		    	TabularSectionRow.DaysWorked);
			StructureOfSelections.Insert("HoursWorked",		        TabularSectionRow.HoursWorked);
			
			// SalesAmountInNationalCurrency
			PresentationCurrency = DriveServer.GetPresentationCurrency(StructureOfSelections.Company);
			If PresentationCurrency = Object.DocumentCurrency Then
				
				StructureOfSelections.Insert("AccountingCurrecyFrequency", 1);
				StructureOfSelections.Insert("AccountingCurrencyExchangeRate", 1);
				StructureOfSelections.Insert("DocumentCurrencyMultiplicity", 1);
				StructureOfSelections.Insert("DocumentCurrencyRate", 1);
				
			Else
				
				ExchangeRatetructure = CurrencyRateOperations.GetCurrencyRate(Object.Date, PresentationCurrency, Object.Company);
				StructureOfSelections.Insert("AccountingCurrecyFrequency", ExchangeRatetructure.Repetition);
				StructureOfSelections.Insert("AccountingCurrencyExchangeRate", ExchangeRatetructure.Rate);
				
				ExchangeRatetructure = CurrencyRateOperations.GetCurrencyRate(Object.Date, Object.DocumentCurrency, Object.Company);
				StructureOfSelections.Insert("DocumentCurrencyMultiplicity", ExchangeRatetructure.Repetition);
				StructureOfSelections.Insert("DocumentCurrencyRate", ExchangeRatetructure.Rate);
				
			EndIf;
			
			TextStr =  " " + NStr("en = 'for the employee in row #'; ru = 'для сотрудника в строке №';pl = 'dla pracownika w wierszu nr';es_ES = 'para el empleado en fila #';es_CO = 'para el empleado en fila #';tr = '# satırındaki çalışan için';it = 'per il dipendente nella riga #';de = 'für den Mitarbeiter in Zeile Nr'") + (Object.EarningsDeductions.IndexOf(TabularSectionRow) + 1);
			
			TabularSectionRow["Value" + Counter] = DriveServer.CalculateParameterValue(StructureOfSelections, CalculationParameter, TextStr);
		
		EndDo;
		
	EndDo; 
	
	FillLoansToEmployees(); //Other calculations. Loans to employees.  
	RefreshFormFooter();
	
EndProcedure

&AtServer
// The procedure calculates the value of the earning or deduction using the formula.
//
Procedure CalculateByFormulas()

	For Each EarningsRow In Object.EarningsDeductions Do
		
		If EarningsRow.ManualCorrection OR Not ValueIsFilled(EarningsRow.EarningAndDeductionType.Formula) Then
			Continue;
		EndIf; 
		
		// 1. Add parameters and values to the structure
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("TariffRate", EarningsRow.Size);
		ParametersStructure.Insert("DaysWorked", EarningsRow.DaysWorked);
		ParametersStructure.Insert("HoursWorked", EarningsRow.HoursWorked);
		
		For Counter = 1 To 3 Do
			If ValueIsFilled(EarningsRow["Presentation" + Counter]) Then
				ParametersStructure.Insert(EarningsRow["Indicator" + Counter], EarningsRow["Value" + Counter]);
			EndIf; 
		EndDo; 
		
		
		// 2. Calculate using formulas
			 
		Formula = EarningsRow.EarningAndDeductionType.Formula;
		For Each Parameter In ParametersStructure Do
			Formula = StrReplace(Formula, "[" + Parameter.Key + "]", Format(Parameter.Value, "NDS=.; NZ=0; NG=0"));
		EndDo;
		Try
			CalculatedSum = Eval(Formula);
		Except
			MessageText = StrTemplate(NStr("en = 'Cannot calculate the Earning amount in the line #%1 The formula may contain an error, or indicators are not filled in.'; ru = 'Не удалось рассчитать сумму начисления в строке №%1. Возможно, формула содержит ошибку или не заполнены показатели.';pl = 'Nie można obliczyć kwoty naliczenie wynagrodzenia w wierszu # %1 Formuła może zawierać błąd lub nie wypełniono wskaźników.';es_ES = 'No se puede calcular el importe de Ingresos en la línea #%1 La fórmula puede contener un error, o los indicadores no se han rellenado.';es_CO = 'No se puede calcular el importe de Ingresos en la línea #%1 La fórmula puede contener un error, o los indicadores no se han rellenado.';tr = '# %1 satırındaki tahakkuk tutarı hesaplanamıyor Formülde bir hata olabilir ya da göstergeler doldurulmamıştır.';it = 'Non è possibile calcolare l''importo maturato nella linea No. %1 Le formula potrebbe contenere un errore, o gli indicatori non sono compilati.';de = 'Der Bezugsbetrag in der Zeile Nr %1 kann nicht berechnet werden. Die Formel kann einen Fehler enthalten, oder es werden keine Kennzeichen ausgefüllt. '"), 
								(Object.EarningsDeductions.IndexOf(EarningsRow) + 1));
			MessageField = "Object.EarningsDeductions[" + Object.EarningsDeductions.IndexOf(EarningsRow) + "].EarningAndDeductionType";
			
			DriveServer.ShowMessageAboutError(Object, MessageText,,,MessageField);
			
			CalculatedSum = 0;
		EndTry;
		EarningsRow.Amount = Round(CalculatedSum, 2); 

	EndDo;
	
	RefreshFormFooter();

EndProcedure

// Gets the data set from the server for the ExpenseGLAccount attribute of the EarningsAndDeductions tabular section
//
&AtServerNoContext
Function GetDataCostsAccount(GLExpenseAccount)
	
	DataStructure = New Structure("TypeOfAccount", Undefined);
	If ValueIsFilled(GLExpenseAccount) Then
		
		DataStructure.TypeOfAccount = GLExpenseAccount.TypeOfAccount;
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction

&AtServer
// Procedure updates data in form footer.
//
Procedure RefreshFormFooter()
	
	Document			= FormAttributeToValue("Object");
	ResultsStructure	= Document.GetDocumentAmount();
	DocumentAmount		= ResultsStructure.DocumentAmount;
	AmountAccrued		= ResultsStructure.AmountAccrued;
	AmountWithheld		= ResultsStructure.AmountWithheld;
	AmountCharged		= ResultsStructure.AmountCharged;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	EarningsDeductions = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "EarningsDeductions");
	GLAccountsInDocuments.CompleteStructureData(EarningsDeductions, ObjectParameters, "EarningsDeductions");
	
	StructureArray.Add(EarningsDeductions);
	
	LoanRepayment = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, "LoanRepayment");
	GLAccountsInDocuments.CompleteStructureData(LoanRepayment, ObjectParameters, "LoanRepayment");
	
	StructureArray.Add(LoanRepayment);
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, GetGLAccounts);
	
EndProcedure

&AtClientAtServerNoContext
Function CreateGeneralAttributeValuesStructure(Form, TabName, TabRow)
	
	Object = Form.Object;
	
	StructureData = New Structure("
	|TabName,
	|Object,
	|UseDefaultTypeOfAccounting,
	|EarningAndDeductionType,
	|GLExpenseAccount,
	|IncomeAndExpenseItems,
	|IncomeAndExpenseItemsFilled,
	|ExpenseItem,
	|IncomeItem,
	|RegisterExpense,
	|RegisterIncome");
	
	FillPropertyValues(StructureData, Form);
	FillPropertyValues(StructureData, Object);
	FillPropertyValues(StructureData, TabRow);
	
	StructureData.Insert("TabName", TabName);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function TypeOfEarningAndDeductionType(EarningAndDeductionType)
	
	Return Common.ObjectAttributeValue(EarningAndDeductionType, "Type");
	
EndFunction

&AtServerNoContext
Function IsIncomeAndExpenseGLA(Account)
	Return GLAccountsInDocumentsServerCall.IsIncomeAndExpenseGLA(Account);
EndFunction

#EndRegion

#Region FormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - initialization of form parameters,
// - setting of the form functional options parameters.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(Object,
	,
	Parameters.CopyingValue,
	Parameters.Basis,
	PostingIsAllowed,
	Parameters.FillingValues);
	
	If Not ValueIsFilled(Object.Ref)
		AND Not (Parameters.FillingValues.Property("RegistrationPeriod") AND ValueIsFilled(Parameters.FillingValues.RegistrationPeriod)) Then
		Object.RegistrationPeriod = BegOfMonth(CurrentSessionDate());
	EndIf;
	
	RegistrationPeriodPresentation = Format(Object.RegistrationPeriod, "DF='MMMM yyyy'");
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	DocumentCurrency = Object.DocumentCurrency;
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	RefreshFormFooter();
	
	If Not Constants.UseSecondaryEmployment.Get() Then
		
		If Items.Find("EarningsDeductionsEmployeeCode") <> Undefined Then
			
			Items.EarningsDeductionsEmployeeCode.Visible = False;
			
		EndIf;
		
		If Items.Find("IncomeTaxesEmployeeCode") <> Undefined Then
			
			Items.IncomeTaxesEmployeeCode.Visible = False;
			
		EndIf;
		
	EndIf;
	
	If Object.EarningsDeductions.Count() > 0 Then
		
		For Each DataRow In Object.EarningsDeductions Do
			
			If ValueIsFilled(DataRow.GLExpenseAccount) Then
				
				DataRow.TypeOfAccount = DataRow.GLExpenseAccount.TypeOfAccount;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	FillAddedColumns();
	
	IncomeAndExpenseItemsInDocuments.SetRegistrationAttributesVisibility(ThisObject,
		"EarningsDeductionsRegisterExpense, EarningsDeductionsRegisterIncome");
	
	SetConditionalAppearance();
	
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
	
	FillAddedColumns();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtClient
// Procedure - form event handler ChoiceProcessing
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ChoiceSource) = Type("ClientApplicationForm")
		And Find(ChoiceSource.FormName, "Calendar") > 0 Then
		
		Object.RegistrationPeriod = EndOfDay(ValueSelected);
		DriveClient.OnChangeRegistrationPeriod(ThisForm);
		
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, ValueSelected);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
// Procedure - Calculate command handler.
//
Procedure Calculate(Command)
	
	CalculateByFormulas();
	
EndProcedure

&AtClient
// The procedure fills in the Employees tabular section with filter by department.
//
Procedure Fill(Command)
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Department is not populated. Document population is canceled.'; ru = 'Не заполнено подразделение! Заполнение документа отменено.';pl = 'Nie wypełniono pola oddziału. Wypełnienie dokumentu było anulowane.';es_ES = 'Departamento no está poblado. La población del documento se ha cancelado.';es_CO = 'Departamento no está poblado. La población del documento se ha cancelado.';tr = 'Bölüm doldurulmamış. Belgenin doldurulması iptal edildi.';it = 'Il reparto non è inserito. La valorizzazione del documento viene annullata.';de = 'Abteilung ist nicht ausgefüllt. Dokumentenbestand wird storniert.'");
		Message.Field = "Object.StructuralUnit";
		Message.Message();
		
		Return;
		
	EndIf;

	If Object.EarningsDeductions.Count() > 0 AND Object.IncomeTaxes.Count() > 0 Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("FillEnd1", ThisObject), NStr("en = 'Document tabular sections will be cleared. Continue?'; ru = 'Табличные части документа будут очищены! Продолжить?';pl = 'Sekcja tabelaryczna zostanie wyczyszczona. Kontynuować?';es_ES = 'Secciones tabulares del documento se limpiarán. ¿Continuar?';es_CO = 'Secciones tabulares del documento se limpiarán. ¿Continuar?';tr = 'Belgenin tablo bölümleri silinecek. Devam edilsin mi?';it = 'La sezione tabellare del documento verranno cancellate. Continua?';de = 'Dokument-Tabellenabschnitte werden gelöscht. Fortsetzen?'"), QuestionDialogMode.YesNo, 0);
        Return;
		
	ElsIf Object.EarningsDeductions.Count() > 0 OR Object.IncomeTaxes.Count() > 0
		OR Object.LoanRepayment.Count() > 0 Then
		
		ShowQueryBox(New NotifyDescription("FillEnd", ThisObject), NStr("en = 'Tabular section of the document will be cleared. Continue?'; ru = 'Табличная часть документа будет очищена! Продолжить?';pl = 'Sekcja tabelaryczna dokumentu zostanie wyczyszczona. Kontynuować?';es_ES = 'Sección tabular del documento se limpiará. ¿Continuar?';es_CO = 'Sección tabular del documento se limpiará. ¿Continuar?';tr = 'Belgenin tablo bölümü temizlenecek. Devam edilsin mi?';it = 'La sezione tabellare del documento verrà cancellata. Continuare?';de = 'Der Tabellenabschnitt des Dokuments wird gelöscht. Fortsetzen?'"), QuestionDialogMode.YesNo, 0);
        Return; 
		
	EndIf;
	
	FillFragment1();
	
EndProcedure

&AtClient
Procedure FillEnd1(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response <> DialogReturnCode.Yes Then
		
		Return;
		
	EndIf;
	
	
	FillFragment1();
	
EndProcedure

&AtClient
Procedure FillFragment1()
	
	FillFragment();
	
EndProcedure

&AtClient
Procedure FillEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response <> DialogReturnCode.Yes Then
		Return;
		
	EndIf; 
	
	
	FillFragment();
	
EndProcedure

&AtClient
Procedure FillFragment()
	
	FillByDepartment();
	FillAddedColumns();
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

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
// Procedure - handler of event OnChange of input field DocumentCurrency.
//
Procedure DocumentCurrencyOnChange(Item)
	
	If Object.DocumentCurrency = DocumentCurrency Then
		Return;
	EndIf; 
	
	If Object.EarningsDeductions.Count() > 0
		Or Object.LoanRepayment.Count() > 0 Then
		
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("DocumentCurrencyOnChangeEnd", ThisObject), NStr("en = 'Tabular section will be cleared. Continue?'; ru = 'Табличная часть будет очищена! Продолжить выполнение операции?';pl = 'Sekcja tabelaryczna zostanie wyczyszczona. Kontynuować?';es_ES = 'Sección tabular se vaciará. ¿Continuar?';es_CO = 'Sección tabular se vaciará. ¿Continuar?';tr = 'Tablo bölümü silinecek. Devam edilsin mi?';it = 'La sezione tabellare sarà annullata. Proseguire?';de = 'Der Tabellenabschnitt wird gelöscht. Fortsetzen?'"), Mode, 0);
		Return;
		
	EndIf; 
	
	DocumentCurrencyOnChangeFragment();
EndProcedure

// Procedure event handler of field management RegistrationPeriod
//
&AtClient
Procedure RegistrationPeriodTuning(Item, Direction, StandardProcessing)
	
	DriveClient.OnRegistrationPeriodRegulation(ThisForm, Direction);
	DriveClient.OnChangeRegistrationPeriod(ThisForm);
	
EndProcedure

// Procedure-handler of the data entry start event of the RegistrationPeriod field
//
&AtClient
Procedure RegistrationPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing	 = False;
	
	CalendarDateOnOpen = ?(ValueIsFilled(Object.RegistrationPeriod), Object.RegistrationPeriod, DriveReUse.GetSessionCurrentDate());
	
	OpenForm("CommonForm.Calendar", DriveClient.GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen), ThisForm);
	
EndProcedure

&AtClient
Procedure DocumentCurrencyOnChangeEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        Object.EarningsDeductions.Clear();
		Object.IncomeTaxes.Clear();
		Object.LoanRepayment.Clear();
	EndIf;
    
    
    DocumentCurrencyOnChangeFragment();

EndProcedure

&AtClient
Procedure DocumentCurrencyOnChangeFragment()
    
    DocumentCurrency = Object.DocumentCurrency;

EndProcedure

&AtClient
Procedure EarningsDeductionsEmployeeOnChange(Item)
	
	If UseDefaultTypeOfAccounting Then
		
		CurrentRow = Items.EarningsDeductions.CurrentData;
		
		DataStructure = New Structure;
		
		DataStructure.Insert("GLExpenseAccount");
		DataStructure.Insert("TypeOfAccount");
		
		DataStructure.Insert("EarningAndDeductionType",		CurrentRow.EarningAndDeductionType);
		DataStructure.Insert("Employee",					CurrentRow.Employee);
		DataStructure.Insert("StartDate",					CurrentRow.StartDate);
		
		GetGLAccountByDefault(DataStructure);
		FillPropertyValues(CurrentRow, DataStructure);
		
	Else
		FillAddedColumns();
	EndIf;
	
EndProcedure

&AtClient
Procedure EarningsDeductionsExpensesAccountOnChange(Item)
	
	DataCurrentRows = Items.EarningsDeductions.CurrentData;
	If DataCurrentRows <> Undefined Then
		
		DataStructure = GetDataCostsAccount(DataCurrentRows.GLExpenseAccount);
		DataCurrentRows.TypeOfAccount = DataStructure.TypeOfAccount;
		
		StructureData = CreateGeneralAttributeValuesStructure(ThisObject, "EarningsDeductions", DataCurrentRows);
		If Item <> Undefined Then
			StructureData.Insert("Manual", True);
		EndIf;
		
		GLAccountsInDocumentsServerCall.CheckItemRegistration(StructureData);
		FillPropertyValues(DataCurrentRows, StructureData);
		
		FillAddedColumns();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EarningsDeductionsExpensesAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataCurrentRows = Items.EarningsDeductions.CurrentData;
	
	DataStructure = New Structure;
	DataStructure.Insert("EarningAndDeductionType", 
		?(DataCurrentRows = Undefined, Undefined, DataCurrentRows.EarningAndDeductionType));
		
	ReceiveDataForSelectAccountsSettlements(DataStructure);
	
	NewArray = New Array;
	NewParameter = New ChoiceParameter("Filter.TypeOfAccount", New FixedArray(DataStructure.GLAccountsAvailableTypes));
	NewArray.Add(NewParameter);
	Items.EarningsDeductionsExpensesAccount.ChoiceParameters = New FixedArray(NewArray);
	
EndProcedure

&AtClient
// Procedure - OnStartEdit event handler of the Earnings tabular section.
//
Procedure EarningsDeductionsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		If Not Copy Then
			
			CurrentData = Items.EarningsDeductions.CurrentData;
			
			CurrentData.StartDate 	= Object.RegistrationPeriod;
			CurrentData.EndDate = EndOfMonth(Object.RegistrationPeriod);
			CurrentData.ManualCorrection = True;
			
		EndIf;
		
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the Earnings tabular section.
//
Procedure EarningsDeductionsOnChange(Item)
	
	RefreshFormFooter();
	
EndProcedure

&AtClient
Procedure EarningsDeductionsStartDateOnChange(Item)
	
	If UseDefaultTypeOfAccounting Then
		
		CurrentRow = Items.EarningsDeductions.CurrentData;
		
		DataStructure = New Structure;
		
		DataStructure.Insert("GLExpenseAccount");
		DataStructure.Insert("TypeOfAccount");
		
		DataStructure.Insert("EarningAndDeductionType",	CurrentRow.EarningAndDeductionType);
		DataStructure.Insert("Employee",				CurrentRow.Employee);
		DataStructure.Insert("StartDate",				CurrentRow.StartDate);
		
		GetGLAccountByDefault(DataStructure);
		FillPropertyValues(CurrentRow, DataStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EarningsDeductionsIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "EarningsDeductions", StandardProcessing);
	
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
// Procedure - OnChange event handler of the Earnings tabular section.
//
Procedure IncomeTaxesOnChange(Item)
	
	RefreshFormFooter();
	
EndProcedure

&AtClient
// Procedure - OnChange event data of the EarningAndDeductionType attribute of the EarningsDeductions tabular section.
//
Procedure EarningsDeductionsEarningAndDeductionTypeOnChange(Item)
	
	CurrentRow = Items.EarningsDeductions.CurrentData;
	
	DataStructure = New Structure;
	DataStructure.Insert("GLExpenseAccount");
	DataStructure.Insert("TypeOfAccount");
	DataStructure.Insert("ExpenseItem");
	DataStructure.Insert("IncomeItem");
	DataStructure.Insert("RegisterExpense");
	DataStructure.Insert("RegisterIncome");
	DataStructure.Insert("EarningAndDeductionType", CurrentRow.EarningAndDeductionType);
	DataStructure.Insert("Employee", CurrentRow.Employee);
	DataStructure.Insert("StartDate", CurrentRow.StartDate);
	
	FillDataStructure(DataStructure);
	FillPropertyValues(CurrentRow, DataStructure);
	
	If UseDefaultTypeOfAccounting Then
		EarningsDeductionsExpensesAccountOnChange(Undefined);
	Else
		FillAddedColumns();
	EndIf;
	
EndProcedure

&AtServer
// Fills the indicators and GL account in the data structure.
//
Function FillDataStructure(DataStructure)
	
	FillIndicators(DataStructure);
	FillIncomeAndExpenses(DataStructure);
	
	If UseDefaultTypeOfAccounting Then
		GetGLAccountByDefault(DataStructure);
	EndIf;
	
	FillAddedColumns();
	
EndFunction

&AtClient
Procedure LoanRepaymentOnChange(Item)
	
	RefreshFormFooter();
	
EndProcedure

&AtClient
Procedure EarningsDeductionsRegisterExpenseOnChange(Item)
	
	CurData = Items.EarningsDeductions.CurrentData;
	If CurData <> Undefined Then
		TypeOfEarningAndDeductionType = TypeOfEarningAndDeductionType(CurData.EarningAndDeductionType);
		If TypeOfEarningAndDeductionType <> PredefinedValue("Enum.EarningAndDeductionTypes.Earning") Then
			CurData.RegisterExpense = Not CurData.RegisterExpense;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure EarningsDeductionsRegisterIncomeOnChange(Item)
	
	CurData = Items.EarningsDeductions.CurrentData;
	If CurData <> Undefined Then
		TypeOfEarningAndDeductionType = TypeOfEarningAndDeductionType(CurData.EarningAndDeductionType);
		If TypeOfEarningAndDeductionType <> PredefinedValue("Enum.EarningAndDeductionTypes.Deduction") Then
			CurData.RegisterIncome = Not CurData.RegisterIncome;
		EndIf;
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

#Region LoansToEmployees

&AtServer
Procedure FillLoansToEmployees()
	
	Object.LoanRepayment.Clear();
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	NestedSelect.Employee
	|INTO UnitEmployees
	|FROM
	|	(SELECT
	|		EmployeesSliceLast.Employee AS Employee
	|	FROM
	|		InformationRegister.Employees.SliceLast(&BeginOfMonth, Company = &Company) AS EmployeesSliceLast
	|	WHERE
	|		EmployeesSliceLast.StructuralUnit = &StructuralUnit
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Employees.Employee
	|	FROM
	|		InformationRegister.Employees AS Employees
	|	WHERE
	|		Employees.StructuralUnit = &StructuralUnit
	|		AND Employees.Period BETWEEN &BeginOfMonth AND &EndOfMonth
	|		AND Employees.Company = &Company) AS NestedSelect
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	LoanSettlements.LoanContract AS LoanContract,
	|	LoanSettlements.LoanContract.SettlementsCurrency AS Currency,
	|	LoanSettlements.PrincipalDebtCurReceipt AS PrincipalDebtCurAccrued,
	|	LoanSettlements.PrincipalDebtCurExpense AS PrincipalDebtCurCharged,
	|	LoanSettlements.InterestCurReceipt AS InterestCurAccrued,
	|	LoanSettlements.InterestCurExpense AS InterestCurCharged,
	|	LoanSettlements.CommissionCurReceipt AS CommissionCurAccrued,
	|	LoanSettlements.CommissionCurExpense AS CommissionCurCharged
	|INTO TemporaryTableAmountAccruedAndChargedWithRegisterRecords
	|FROM
	|	AccumulationRegister.LoanSettlements.Turnovers(
	|			,
	|			,
	|			,
	|			LoanContract.ChargeFromSalary
	|				AND Company = &Company
	|				AND LoanContract.LoanKind = &LoanKindLoanContract
	|				AND LoanKind = &LoanKindLoanContract
	|				AND LoanContract.SettlementsCurrency = &Currency
	|				AND Counterparty IN
	|					(SELECT DISTINCT
	|						UnitEmployees.Employee
	|					FROM
	|						UnitEmployees AS UnitEmployees)) AS LoanSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	LoanSettlements.LoanContract,
	|	LoanSettlements.LoanContract.SettlementsCurrency,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -LoanSettlements.PrincipalDebtCur
	|		ELSE LoanSettlements.PrincipalDebtCur
	|	END,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN -LoanSettlements.PrincipalDebtCur
	|		ELSE LoanSettlements.PrincipalDebtCur
	|	END,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -LoanSettlements.InterestCur
	|		ELSE LoanSettlements.InterestCur
	|	END,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN -LoanSettlements.InterestCur
	|		ELSE LoanSettlements.InterestCur
	|	END,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -LoanSettlements.CommissionCur
	|		ELSE LoanSettlements.CommissionCur
	|	END,
	|	CASE
	|		WHEN LoanSettlements.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN -LoanSettlements.CommissionCur
	|		ELSE LoanSettlements.CommissionCur
	|	END
	|FROM
	|	AccumulationRegister.LoanSettlements AS LoanSettlements
	|WHERE
	|	LoanSettlements.Recorder = &Ref
	|	AND LoanSettlements.LoanContract.ChargeFromSalary
	|	AND LoanSettlements.Company = &Company
	|	AND LoanSettlements.LoanContract.LoanKind = &LoanKindLoanContract
	|	AND LoanSettlements.LoanKind = &LoanKindLoanContract
	|	AND LoanSettlements.Counterparty IN
	|			(SELECT DISTINCT
	|				UnitEmployees.Employee
	|			FROM
	|				UnitEmployees AS UnitEmployees)
	|	AND LoanSettlements.LoanContract.SettlementsCurrency = &Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableAmountAccruedAndChargedWithRegisterRecords.LoanContract,
	|	TemporaryTableAmountAccruedAndChargedWithRegisterRecords.Currency,
	|	SUM(TemporaryTableAmountAccruedAndChargedWithRegisterRecords.PrincipalDebtCurAccrued) AS PrincipalDebtCurAccrued,
	|	SUM(TemporaryTableAmountAccruedAndChargedWithRegisterRecords.PrincipalDebtCurCharged) AS PrincipalDebtCurCharged,
	|	SUM(TemporaryTableAmountAccruedAndChargedWithRegisterRecords.InterestCurAccrued) AS InterestCurAccrued,
	|	SUM(TemporaryTableAmountAccruedAndChargedWithRegisterRecords.InterestCurCharged) AS InterestCurCharged,
	|	SUM(TemporaryTableAmountAccruedAndChargedWithRegisterRecords.CommissionCurAccrued) AS CommissionCurAccrued,
	|	SUM(TemporaryTableAmountAccruedAndChargedWithRegisterRecords.CommissionCurCharged) AS CommissionCurCharged
	|INTO TemporaryTableAmountAccruedAndCharged
	|FROM
	|	TemporaryTableAmountAccruedAndChargedWithRegisterRecords AS TemporaryTableAmountAccruedAndChargedWithRegisterRecords
	|
	|GROUP BY
	|	TemporaryTableAmountAccruedAndChargedWithRegisterRecords.LoanContract,
	|	TemporaryTableAmountAccruedAndChargedWithRegisterRecords.Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	LoanRepaymentSchedule.LoanContract AS LoanContract,
	|	LoanRepaymentSchedule.LoanContract.SettlementsCurrency AS LoanContractCurrency,
	|	SUM(LoanRepaymentSchedule.Principal) AS PrincipalAmountSchedule,
	|	SUM(LoanRepaymentSchedule.Interest) AS InterestAmountSchedule,
	|	SUM(LoanRepaymentSchedule.Commission) AS CommissionAmountSchedule
	|INTO TemporaryTableAmountToCharge
	|FROM
	|	UnitEmployees AS UnitEmployees
	|		INNER JOIN InformationRegister.LoanRepaymentSchedule AS LoanRepaymentSchedule
	|		ON UnitEmployees.Employee = LoanRepaymentSchedule.LoanContract.Employee
	|WHERE
	|	LoanRepaymentSchedule.Period <= &EndOfMonth
	|	AND LoanRepaymentSchedule.LoanContract.SettlementsCurrency = &Currency
	|
	|GROUP BY
	|	LoanRepaymentSchedule.LoanContract,
	|	LoanRepaymentSchedule.LoanContract.SettlementsCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableAmountToCharge.LoanContract AS LoanContract,
	|	TemporaryTableAmountToCharge.LoanContractCurrency AS Currency,
	|	TemporaryTableAmountToCharge.PrincipalAmountSchedule,
	|	TemporaryTableAmountToCharge.InterestAmountSchedule,
	|	TemporaryTableAmountToCharge.CommissionAmountSchedule,
	|	ISNULL(TemporaryTableAmountAccruedAndCharged.PrincipalDebtCurAccrued, 0) AS PrincipalDebtCurAccrued,
	|	ISNULL(TemporaryTableAmountAccruedAndCharged.PrincipalDebtCurCharged, 0) AS PrincipalDebtCurCharged,
	|	ISNULL(TemporaryTableAmountAccruedAndCharged.InterestCurAccrued, 0) AS InterestCurAccrued,
	|	ISNULL(TemporaryTableAmountAccruedAndCharged.InterestCurCharged, 0) AS InterestCurCharged,
	|	ISNULL(TemporaryTableAmountAccruedAndCharged.CommissionCurAccrued, 0) AS CommissionCurAccrued,
	|	ISNULL(TemporaryTableAmountAccruedAndCharged.CommissionCurCharged, 0) AS CommissionCurCharged,
	|	TemporaryTableAmountAccruedAndCharged.LoanContract.Employee AS Employee,
	|	TemporaryTableAmountAccruedAndCharged.LoanContract.Total AS TotalAmountOfLoan
	|FROM
	|	TemporaryTableAmountToCharge AS TemporaryTableAmountToCharge
	|		LEFT JOIN TemporaryTableAmountAccruedAndCharged AS TemporaryTableAmountAccruedAndCharged
	|		ON TemporaryTableAmountToCharge.LoanContract = TemporaryTableAmountAccruedAndCharged.LoanContract";
	
	Query.SetParameter("BeginOfMonth", Object.RegistrationPeriod);
	Query.SetParameter("EndOfMonth", EndOfMonth(Object.RegistrationPeriod));
	Query.SetParameter("Company", DriveServer.GetCompany(Object.Company));
	Query.SetParameter("Currency", Object.DocumentCurrency);
	Query.SetParameter("LoanKindLoanContract", Enums.LoanContractTypes.EmployeeLoanAgreement);
	Query.SetParameter("Ref", Object.Ref);
	Query.SetParameter("StructuralUnit", Object.StructuralUnit);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		
		// If the money under the loan agreement hasn't been paid, then we will not repay.
		If Selection.PrincipalDebtCurAccrued = 0 Then
			Continue;	
		EndIf;
		
		NeedToRepayLoan = Selection.PrincipalAmountSchedule - Selection.PrincipalDebtCurCharged;
		NeedToRepayLoan = ?(NeedToRepayLoan < 0, 0, NeedToRepayLoan);
		NeedToRepayLoan = ?(Selection.PrincipalDebtCurCharged > Selection.TotalAmountOfLoan, 0, NeedToRepayLoan);
		
		InterestAccrued = (Selection.InterestAmountSchedule + Selection.CommissionAmountSchedule) - (Selection.InterestCurAccrued + Selection.CommissionCurAccrued);
		InterestAccrued = ?(InterestAccrued < 0, 0, InterestAccrued);
		
		InterestCharged = (Selection.InterestAmountSchedule + Selection.CommissionAmountSchedule) - (Selection.InterestCurCharged + Selection.CommissionCurCharged);
		InterestCharged = ?(InterestCharged < 0, 0, InterestCharged);
		
		If NeedToRepayLoan > 0 OR InterestAccrued > 0 Then
			NewRow = Object.LoanRepayment.Add();
			FillPropertyValues(NewRow, Selection);
			NewRow.PrincipalCharged	= NeedToRepayLoan;
			NewRow.InterestAccrued	= InterestAccrued;
			NewRow.InterestCharged	= InterestCharged;
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion