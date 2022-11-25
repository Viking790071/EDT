#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Function returns the tabular section filled with
// the scheduled earnings and deductions of employee
//
// Parameters:
//  FilterStructure - Structure contained data of person
//                 for who it is necessary to find earnings or deductions      
//
// Returns:
//  ValueTable with received earnings or deductions.
//
Function FindEmployeeEarningsDeductions(FilterStructure, Tax = False) Export

	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	CompensationPlanSliceLast.EarningAndDeductionType AS EarningAndDeductionType,
	|	CompensationPlanSliceLast.Currency AS Currency,
	|	CASE
	|		WHEN CompensationPlanSliceLast.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN CompensationPlanSliceLast.IncomeAndExpenseItem
	|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	END AS ExpenseItem,
	|	CASE
	|		WHEN CompensationPlanSliceLast.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|			THEN CompensationPlanSliceLast.IncomeAndExpenseItem
	|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	END AS IncomeItem,
	|	CompensationPlanSliceLast.GLExpenseAccount AS GLExpenseAccount,
	|	CompensationPlanSliceLast.Amount AS Amount,
	|	CompensationPlanSliceLast.Actuality AS Actuality
	|FROM
	|	InformationRegister.CompensationPlan.SliceLast(
	|			&Date,
	|			Employee = &Employee
	|				AND Company = &Company
	|				AND Recorder <> &Recorder
	|				AND CASE
	|					WHEN &Tax
	|						THEN EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Tax)
	|					ELSE EarningAndDeductionType.Type <> VALUE(Enum.EarningAndDeductionTypes.Tax)
	|				END) AS CompensationPlanSliceLast
	|WHERE
	|	CompensationPlanSliceLast.Actuality";
	
	Query.SetParameter("Employee", FilterStructure.Employee);
	Query.SetParameter("Company", DriveServer.GetCompany(FilterStructure.Company));
	Query.SetParameter("Date", FilterStructure.Date);
	Query.SetParameter("Recorder", Ref); 
	Query.SetParameter("Tax", Tax);
	
	ResultTable = Query.Execute().Unload();
	ResultArray = New Array;
	For Each TSRow In ResultTable Do
		
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("EarningAndDeductionType", TSRow.EarningAndDeductionType);
		TabularSectionRow.Insert("Currency", TSRow.Currency);
		TabularSectionRow.Insert("ExpenseItem", TSRow.ExpenseItem);
		TabularSectionRow.Insert("IncomeItem", TSRow.IncomeItem);
		TabularSectionRow.Insert("GLExpenseAccount", TSRow.GLExpenseAccount);
		TabularSectionRow.Insert("Amount", TSRow.Amount);
		TabularSectionRow.Insert("Actuality", TSRow.Actuality);
		
		ResultArray.Add(TabularSectionRow);
		
	EndDo;
	
	Return ResultArray;
	
EndFunction

// Controls conflicts.
//
Procedure RunPreliminaryControl(Cancel) 
	
	Query = New Query(
	"SELECT ALLOWED
	|	StaffDisplacementEmployees.LineNumber,
	|	StaffDisplacementEmployees.Employee,
	|	StaffDisplacementEmployees.Period,
	|	StaffDisplacementEmployees.ConnectionKey
	|INTO TableEmployees
	|FROM
	|	Document.TransferAndPromotion.Employees AS StaffDisplacementEmployees
	|WHERE
	|	StaffDisplacementEmployees.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TableEarningsDeductions.LineNumber,
	|	TableEarningsDeductions.EarningAndDeductionType,
	|	TableEarningsDeductions.Currency,
	|	TableEmployees.Employee,
	|	TableEmployees.Period
	|INTO TableEarningsDeductions
	|FROM
	|	Document.TransferAndPromotion.EarningsDeductions AS TableEarningsDeductions
	|		INNER JOIN TableEmployees AS TableEmployees
	|		ON TableEarningsDeductions.ConnectionKey = TableEmployees.ConnectionKey
	|			AND (TableEarningsDeductions.Ref = &Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TableEmployees.LineNumber AS LineNumber,
	|	Employees.Recorder
	|FROM
	|	TableEmployees AS TableEmployees
	|		INNER JOIN InformationRegister.Employees AS Employees
	|		ON (Employees.Company = &Company)
	|			AND TableEmployees.Employee = Employees.Employee
	|			AND TableEmployees.Period = Employees.Period
	|			AND (Employees.Recorder <> &Ref)
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TableEarningsDeductions.LineNumber AS LineNumber,
	|	CompensationPlan.Recorder
	|FROM
	|	InformationRegister.CompensationPlan AS CompensationPlan
	|		INNER JOIN TableEarningsDeductions AS TableEarningsDeductions
	|		ON (CompensationPlan.Company = &Company)
	|			AND CompensationPlan.Employee = TableEarningsDeductions.Employee
	|			AND CompensationPlan.EarningAndDeductionType = TableEarningsDeductions.EarningAndDeductionType
	|			AND CompensationPlan.Currency = TableEarningsDeductions.Currency
	|			AND CompensationPlan.Period = TableEarningsDeductions.Period
	|			AND (CompensationPlan.Recorder <> &Ref)
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(TableEmployeesTwinsRows.LineNumber) AS LineNumber,
	|	TableEmployeesTwinsRows.Employee
	|FROM
	|	TableEmployees AS TableEmployees
	|		INNER JOIN TableEmployees AS TableEmployeesTwinsRows
	|		ON TableEmployees.LineNumber <> TableEmployeesTwinsRows.LineNumber
	|			AND TableEmployees.Employee = TableEmployeesTwinsRows.Employee
	|
	|GROUP BY
	|	TableEmployeesTwinsRows.Employee
	|
	|ORDER BY
	|	LineNumber");
	
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Register "Employees".
	If Not ResultsArray[2].IsEmpty() Then
		QueryResultSelection = ResultsArray[2].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en = 'In row #%Number% of the ""Employees"" tabular section, the order validity contradicts the ""%PersonnelOrder%"" personnel order.'; ru = 'В строке №%Number% табл. части ""Сотрудники"" период действия приказа противоречит кадровому приказу ""%PersonnelOrder%"".';pl = 'W wierszu nr %Number% sekcji tabelarycznej ""Pracownicy"" okres aktualności zlecenia różni się od zlecenia kadrowego ""%PersonnelOrder%"".';es_ES = 'En la fila #%Number% de la sección tabular ""Empleados"", la validez del orden contradice el orden de empleados ""%PersonnelOrder%"".';es_CO = 'En la fila #%Number% de la sección tabular ""Empleados"", la validez del orden contradice el orden de empleados ""%PersonnelOrder%"".';tr = '""Çalışanlar"" tablo bölümünün #%Number% satırında, emir geçerliliği ""%PersonnelOrder%"" personel emri ile çelişiyor.';it = 'Nella riga #%Number% della sezione tabellare ""Dipendenti"",la validità dell''ordine è in contrasto con l''ordine del personale ""%PersonnelOrder%"".';de = 'In der Zeile Nr %Number% des Tabellenabschnitts ""Mitarbeiter"" widerspricht die Auftragsgültigkeit dem ""%PersonnelOrder%"" Personalauftrag.'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%PersonnelOrder%", QueryResultSelection.Recorder);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				QueryResultSelection.LineNumber,
				"Period",
				Cancel);
		EndDo;
	EndIf;

	// Register "Planned earnings and deductions".
	If Not ResultsArray[3].IsEmpty() Then
		QueryResultSelection = ResultsArray[3].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en = 'In row #%Number% of the ""Earnings and deductions"" tabular section, the order validity contradicts the ""%PersonnelOrder%"" personnel order.'; ru = 'В строке №%Number% табл. части ""Начисления и удержания"" период действия приказа противоречит кадровому приказу ""%PersonnelOrder%"".';pl = 'W wierszu nr %Number% sekcji tabelarycznej ""Zarobki i potrącenia"" okres aktualności zlecenia różni się od zlecenia kadrowego ""%PersonnelOrder%"".';es_ES = 'En la fila #%Number% de la sección tabular ""Ingresos y deducciones"", la validez del orden contradice el orden de empleados ""%PersonnelOrder%"".';es_CO = 'En la fila #%Number% de la sección tabular ""Ingresos y deducciones"", la validez del orden contradice el orden de empleados ""%PersonnelOrder%"".';tr = '""Kazanç ve kesintiler"" tablo bölümünün # %Number% satırında, emir geçerliliği""%PersonnelOrder%"" personel emri ile çelişiyor.';it = 'Nella riga #%Number% della sezione tabellare ""Compensi e trattenute"", la validità dell''ordine contraddice l''ordine del personale ""%PersonnelOrder%"".';de = 'In der Zeile Nr %Number% des Tabellenabschnitts ""Bezüge und Abzüge"" widerspricht die Auftragsgültigkeit dem ""%PersonnelOrder%"" Personalauftrag.'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%PersonnelOrder%", QueryResultSelection.Recorder);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"EarningsDeductions",
				QueryResultSelection.LineNumber,
				"Period",
				Cancel);
		EndDo;
	EndIf;
	
	// Row duplicates.
	If Not ResultsArray[4].IsEmpty() Then
		QueryResultSelection = ResultsArray[4].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en = 'In row #%Number% of the ""Employees"" tabular section, the employee is specified again.'; ru = 'В строке №%Number% табл. части ""Сотрудники"" сотрудник указывается повторно.';pl = 'W wierszu nr %Number% sekcji tabelarycznej ""Pracownicy"" pracownik jest określany ponownie.';es_ES = 'En la fila #%Number% de la sección tabular ""Empleados"", el empleado está especificado de nuevo.';es_CO = 'En la fila #%Number% de la sección tabular ""Empleados"", el empleado está especificado de nuevo.';tr = '""Çalışanlar"" tablo bölümü # %Number% satırında, çalışan yeniden belirlenmiş.';it = 'Nella riga #%Number% della sezione tabellare ""Dipendenti"", il dipendente è specificato nuovamente.';de = 'In der Zeile Nr %Number% des Tabellenabschnitts ""Mitarbeiter"" wird der Mitarbeiter erneut angegeben.'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				QueryResultSelection.LineNumber,
				"Employee",
				Cancel);
		EndDo;
	EndIf;	 
	
EndProcedure

// Controls conflicts.
//
Procedure RunControl(AdditionalProperties, Cancel) 
	
	If Cancel Then
		Return;	
	EndIf;
	
	Query = New Query(
	"SELECT
	|	NestedSelect.Employee,
	|	NestedSelect.LineNumber AS LineNumber,
	|	Employees.StructuralUnit
	|FROM
	|	(SELECT
	|		TableEmployees.Employee AS Employee,
	|		TableEmployees.LineNumber AS LineNumber,
	|		MAX(Employees.Period) AS Period
	|	FROM
	|		TableEmployees AS TableEmployees
	|			LEFT JOIN InformationRegister.Employees AS Employees
	|			ON (Employees.Employee = TableEmployees.Employee)
	|				AND (Employees.Company = &Company)
	|				AND (Employees.Period <= TableEmployees.Period)
	|				AND (Employees.Recorder <> &Ref)
	|	
	|	GROUP BY
	|		TableEmployees.Employee,
	|		TableEmployees.LineNumber) AS NestedSelect
	|		LEFT JOIN InformationRegister.Employees AS Employees
	|		ON NestedSelect.Employee = Employees.Employee
	|			AND NestedSelect.Period = Employees.Period
	|			AND (Employees.Company = &Company)
	|
	|ORDER BY
	|	LineNumber");
	
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	Result = Query.Execute();
	
	// Employee is not employed by the company as of the date of occupation change.
	QueryResultSelection = Result.Select();
	While QueryResultSelection.Next() Do
		If Not ValueIsFilled(QueryResultSelection.StructuralUnit) Then
		    MessageText = NStr("en = 'In row #%Number% of the ""Employees"" tabular section, it is indicated that the %Employee% employee is not hired to the %Company% company.'; ru = 'В строке №%Number% табл. части ""Сотрудники"" сотрудник %Employee% не принят на работу в организацию %Company%.';pl = 'W wierszu nr %Number% sekcji tabelarycznej ""Pracownicy"" pracownik %Employee% nie jest przyjęty do pracy w firmie %Company%.';es_ES = 'En la fila #%Number% de la sección tabular ""Empleados"", está indicado que el empleado %Employee% no está contratado para la empresa %Company%.';es_CO = 'En la fila #%Number% de la sección tabular ""Empleados"", está indicado que el empleado %Employee% no está contratado para la empresa %Company%.';tr = '""Çalışanlar"" tablo bölümünün no. %Number% satırında, %Employee% çalışanının %Company% iş yerine kiralanmadığını gösterir.';it = 'Nella riga #%Number% della sezione tabellare ""Dipendenti"", è indicato che il dipendente %Employee% non è assunto presso l''azienda %Company%.';de = 'In der Zeile Nr %Number% des Tabellenabschnitts ""Mitarbeiter"" wird angegeben, dass der %Employee% Mitarbeiter nicht bei der %Company% Firma eingestellt ist.'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%Employee%", QueryResultSelection.Employee); 
			MessageText = StrReplace(MessageText, "%Company%", AdditionalProperties.ForPosting.Company);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				QueryResultSelection.LineNumber,
				"Employee",
				Cancel);
		EndIf; 
	EndDo;	 
	
EndProcedure

// Controls the staff list.
//
Procedure RunControlStaffSchedule(AdditionalProperties, Cancel) 
	
	If Cancel OR Not Constants.UseHeadcountBudget.Get() Then
		Return;	
	EndIf;
	
	If OperationKind = Enums.OperationTypesTransferAndPromotion.PaymentFormChange Then
		Return;
	EndIf; 
	
	Query = New Query("
	|SELECT
	|	CASE
	|		WHEN ISNULL(TotalStaffList.CountOfRatesBySSh, 0) - ISNULL(TotalBusyBids.OccupiedRates, 0) < 0
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS FontsContradiction,
	|	CASE
	|		WHEN TotalStaffList.LineNumber IS NULL 
	|			THEN TotalBusyBids.LineNumber
	|		ELSE TotalStaffList.LineNumber
	|	END AS LineNumber
	|FROM
	|	(SELECT
	|		StaffListMaxPeriods.LineNumber AS LineNumber,
	|		HeadcountBudget.NumberOfRates AS CountOfRatesBySSh,
	|		HeadcountBudget.StructuralUnit AS StructuralUnit,
	|		HeadcountBudget.Position AS Position,
	|		HeadcountBudget.Company AS Company
	|	FROM
	|		(SELECT
	|			HeadcountBudget.Company AS Company,
	|			HeadcountBudget.StructuralUnit AS StructuralUnit,
	|			HeadcountBudget.Position AS Position,
	|			MAX(HeadcountBudget.Period) AS Period,
	|			StaffDisplacementEmployees.LineNumber AS LineNumber
	|		FROM
	|			Document.TransferAndPromotion.Employees AS StaffDisplacementEmployees
	|				INNER JOIN InformationRegister.HeadcountBudget AS HeadcountBudget
	|				ON (HeadcountBudget.Company = &Company)
	|					AND StaffDisplacementEmployees.StructuralUnit = HeadcountBudget.StructuralUnit
	|					AND StaffDisplacementEmployees.Position = HeadcountBudget.Position
	|					AND StaffDisplacementEmployees.Period >= HeadcountBudget.Period
	|		WHERE
	|			StaffDisplacementEmployees.Ref = &Ref
	|		
	|		GROUP BY
	|			HeadcountBudget.Position,
	|			HeadcountBudget.StructuralUnit,
	|			HeadcountBudget.Company,
	|			StaffDisplacementEmployees.LineNumber) AS StaffListMaxPeriods
	|			LEFT JOIN InformationRegister.HeadcountBudget AS HeadcountBudget
	|			ON StaffListMaxPeriods.Period = HeadcountBudget.Period
	|				AND StaffListMaxPeriods.Company = HeadcountBudget.Company
	|				AND StaffListMaxPeriods.StructuralUnit = HeadcountBudget.StructuralUnit
	|				AND StaffListMaxPeriods.Position = HeadcountBudget.Position) AS TotalStaffList
	|		Full JOIN (SELECT
	|			Employees.StructuralUnit AS StructuralUnit,
	|			Employees.Position AS Position,
	|			SUM(Employees.OccupiedRates) AS OccupiedRates,
	|			Employees.Company AS Company,
	|			EmployeesMaximalPeriods.LineNumber AS LineNumber
	|		FROM
	|			(SELECT
	|				Employees.Company AS Company,
	|				MAX(Employees.Period) AS Period,
	|				StaffDisplacementEmployees.LineNumber AS LineNumber,
	|				Employees.Employee AS Employee,
	|				StaffDisplacementEmployees.StructuralUnit AS StructuralUnit,
	|				StaffDisplacementEmployees.Position AS Position
	|			FROM
	|				Document.TransferAndPromotion.Employees AS StaffDisplacementEmployees
	|					LEFT JOIN InformationRegister.Employees AS Employees
	|					ON (Employees.Company = &Company)
	|						AND StaffDisplacementEmployees.Period >= Employees.Period
	|			WHERE
	|				StaffDisplacementEmployees.Ref = &Ref
	|			
	|			GROUP BY
	|				Employees.Company,
	|				StaffDisplacementEmployees.LineNumber,
	|				Employees.Employee,
	|				StaffDisplacementEmployees.StructuralUnit,
	|				StaffDisplacementEmployees.Position) AS EmployeesMaximalPeriods
	|				INNER JOIN InformationRegister.Employees AS Employees
	|				ON (Employees.Company = &Company)
	|					AND EmployeesMaximalPeriods.Employee = Employees.Employee
	|					AND EmployeesMaximalPeriods.StructuralUnit = Employees.StructuralUnit
	|					AND EmployeesMaximalPeriods.Position = Employees.Position
	|					AND EmployeesMaximalPeriods.Period = Employees.Period
	|		WHERE
	|			Employees.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|		
	|		GROUP BY
	|			Employees.StructuralUnit,
	|			Employees.Position,
	|			Employees.Company,
	|			EmployeesMaximalPeriods.LineNumber) AS TotalBusyBids
	|		ON TotalStaffList.LineNumber = TotalBusyBids.LineNumber
	|
	|ORDER BY
	|	LineNumber");
						  
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		If Selection.FontsContradiction Then
			MessageText = NStr("en = 'Row #%Number% of the ""Employees"" tabular section: employment rates are not provided in the staff list.'; ru = 'Строка №%Number% табл. части ""Сотрудники"": в штатном расписании не предусмотрены ставки для приема сотрудника!';pl = 'Wiersz nr %Number% sekcji tabelarycznej ""Pracownicy"": na liście pracowników brak wolnych stanowisk do zatrudnienia pracownika.';es_ES = 'La fila #%Number% de la sección tabular ""Empleados"": tipos de empleo no están proporcionados en la lista de empleados.';es_CO = 'La fila #%Number% de la sección tabular ""Empleados"": tipos de empleo no están proporcionados en la lista de empleados.';tr = '""Çalışanlar"" tablo bölümünün #%Number% satırı: istihdam oranları çalışan listesinde bulunmaz.';it = 'Riga #%Number% della sezione tabellare ""Dipendenti"": i tassi di occupazione non sono forniti nell''elenco del personale.';de = 'Zeile Nr %Number% des Tabellenabschnitts ""Mitarbeiter"": Die Beschäftigungsquoten werden in der Mitarbeiterliste nicht angegeben.'");
			MessageText = StrReplace(MessageText, "%Number%", Selection.LineNumber);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				Selection.LineNumber,
				"OccupiedRates",
				);
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region EventHandlers

// IN handler of document event FillCheckProcessing,
// checked attributes are being copied and reset
// to exclude a standard platform fill check and subsequent check by embedded language tools.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Precheck
	RunPreliminaryControl(Cancel);
	
	If OperationKind = Enums.OperationTypesTransferAndPromotion.TransferAndPaymentFormChange Then
		CheckedAttributes.Add("Employees.StructuralUnit");
		CheckedAttributes.Add("Employees.Position");
		CheckedAttributes.Add("Employees.CurrentPositions");
	EndIf;
	
	For Each Row In EarningsDeductions Do
		
		TypeOfEarningAndDeductionType = Common.ObjectAttributeValue(Row.EarningAndDeductionType, "Type");
		
		If TypeOfEarningAndDeductionType = Enums.EarningAndDeductionTypes.Earning And Not ValueIsFilled(Row.ExpenseItem) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'On the ""Earnings and deductions"" tab, in line #%1, an expense item is required.'; ru = 'На вкладке ""Начисления и удержания"" в строке %1 требуется указать статью расходов.';pl = 'Na karcie ""Zarobki i potrącenia"", w wierszu nr %1, pozycja rozchodów jest wymagana.';es_ES = 'En la pestaña Ingresos y deducciones, en la línea #%1, se requiere un artículo de gastos.';es_CO = 'En la pestaña Ingresos y deducciones, en la línea #%1, se requiere un artículo de gastos.';tr = '""Kazançlar ve kesintiler"" sekmesinin %1 nolu satırında gider kalemi gerekli.';it = 'Nella scheda ""Compensi e trattenute"", nella riga #%1, è richiesta una voce di uscita.';de = 'Eine Position von Ausgaben ist in der Zeile Nr. %1 auf der Registerkarte ""Bezüge und Abzüge"" erforderlich.'"),
				String(Row.LineNumber));
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"EarningsDeductions",
				Row.LineNumber,
				"ExpenseItem",
				Cancel);
		ElsIf TypeOfEarningAndDeductionType = Enums.EarningAndDeductionTypes.Deduction And Not ValueIsFilled(Row.IncomeItem) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'On the ""Earnings and deductions"" tab, in line #%1, an income item is required.'; ru = 'На вкладке ""Начисления и удержания"" в строке %1 требуется указать статью доходов.';pl = 'Na karcie ""Zarobki i potrącenia"", w wierszu nr %1, pozycja dochodów jest wymagana.';es_ES = 'En la pestaña Ingresos y deducciones, en la línea #%1, se requiere un artículo de ingresos.';es_CO = 'En la pestaña Ingresos y deducciones, en la línea #%1, se requiere un artículo de ingresos.';tr = '""Kazançlar ve kesintiler"" sekmesinin %1 nolu satırında gelir kalemi gerekli.';it = 'Nella scheda ""Compensi e trattenute"", nella riga #%1, è richiesta una voce di entrata.';de = 'Eine Position von Einnahme ist in der Zeile Nr. %1 auf der Registerkarte ""Bezüge und Abzüge"" erforderlich.'"),
				String(Row.LineNumber));
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"EarningsDeductions",
				Row.LineNumber,
				"IncomeItem",
				Cancel);
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.TransferAndPromotion.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectEmployees(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCompensationPlan(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	RunControl(AdditionalProperties, Cancel);
	RunControlStaffSchedule(AdditionalProperties, Cancel);	
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
		
EndProcedure

#EndRegion

#EndIf
