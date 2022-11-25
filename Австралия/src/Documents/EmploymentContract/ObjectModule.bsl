#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Controls conflicts.
//
Procedure RunPreliminaryControl(Cancel)
	
	TableEmployees 			= Employees.Unload(,"LineNumber, Employee, Period, ConnectionKey");
	TableEarningsDeductions 	= EarningsDeductions.Unload(,"LineNumber, EarningAndDeductionType, Currency, ConnectionKey");
	
	// Add columns and fill by connection key. 
	// Link is mandatory and it must correspond to one employee only.
	TableEarningsDeductions.Columns.Add("Employee", New TypeDescription("CatalogRef.Employees"));
	TableEarningsDeductions.Columns.Add("Period", New TypeDescription("Date"));
	
	For Each EarningDetentionRow In TableEarningsDeductions Do
		
		RowsOfEmployeesArray = TableEmployees.FindRows(New Structure("ConnectionKey", EarningDetentionRow.ConnectionKey));
		
		If RowsOfEmployeesArray.Count() = 1 Then
			
			EarningDetentionRow.Employee	= RowsOfEmployeesArray[0].Employee;
			EarningDetentionRow.Period	= RowsOfEmployeesArray[0].Period;
			
		Else
			
			// Erroneous link, it must not exist, but the check remains
			MessageText = NStr("en = 'Invalid link condition in row #%Number% of the ""Earnings and deductions"" tabular section.'; ru = 'Не верное условие связи в строке №%Number% табл. части ""Начислений и удержаний"".';pl = 'Nieprawidłowy odsyłacz w wierszu nr %Number% sekcji tabelarycznej ""Zarobki i potrącenia"".';es_ES = 'Condición del enlace inválida en la fila #%Number% de la sección tabular ""Ingresos y deducciones"".';es_CO = 'Condición del enlace inválida en la fila #%Number% de la sección tabular ""Ingresos y deducciones"".';tr = '""Kazançlar ve kesintiler"" tablo bölümünün #%Number% satırında geçersiz bağlantı koşulu.';it = 'Condizione di collegamento non valida nella riga #%Number% della sezione tabellare ""Compensi e trattenute"".';de = 'Ungültige Linkbedingung in Zeile Nr %Number% des Tabellenabschnitts ""Bezüge und Abzüge"".'");
			MessageText = StrReplace(MessageText, "%Number%", EarningDetentionRow.LineNumber); 
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"EarningsDeductions",
				 EarningDetentionRow.LineNumber,
				"LineNumber",
				Cancel);
			
		EndIf;
		
	EndDo;
	
	Query = New Query(
	"SELECT 
	|	EmploymentContractEmployees.LineNumber,
	|	EmploymentContractEmployees.Employee,
	|	EmploymentContractEmployees.Period,
	|	EmploymentContractEmployees.ConnectionKey
	|INTO TableEmployees
	|FROM
	|	&TableEmployees AS EmploymentContractEmployees
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT 
	|	TableEarningsDeductions.LineNumber,
	|	TableEarningsDeductions.EarningAndDeductionType,
	|	TableEarningsDeductions.Currency,
	|	TableEarningsDeductions.Employee,
	|	TableEarningsDeductions.Period
	|INTO TableEarningsDeductions
	|FROM
	|	&TableEarningsDeductions AS TableEarningsDeductions
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
	
	
	Query.SetParameter("Ref", 					Ref);
	Query.Parameters.Insert("Company", 				DriveServer.GetCompany(Company));
	Query.Parameters.Insert("TableEmployees", 			TableEmployees);
	Query.Parameters.Insert("TableEarningsDeductions", TableEarningsDeductions);
	
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
				"EarningAndDeductionType",
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
	"SELECT ALLOWED
	|	NestedSelect.Employee,
	|	NestedSelect.LineNumber,
	|	Employees.StructuralUnit
	|FROM
	|	(SELECT
	|		TableEmployees.Employee AS Employee,
	|		TableEmployees.LineNumber AS LineNumber,
	|		MAX(Employees.Period) AS Period
	|	FROM
	|		InformationRegister.Employees AS Employees
	|			INNER JOIN TableEmployees AS TableEmployees
	|			ON Employees.Employee = TableEmployees.Employee
	|				AND (Employees.Company = &Company)
	|				AND Employees.Period <= TableEmployees.Period
	|				AND (Employees.Recorder <> &Ref)
	|	
	|	GROUP BY
	|		TableEmployees.Employee,
	|		TableEmployees.LineNumber) AS NestedSelect
	|		INNER JOIN InformationRegister.Employees AS Employees
	|		ON NestedSelect.Employee = Employees.Employee
	|			AND NestedSelect.Period = Employees.Period
	|			AND (Employees.Company = &Company)
	|WHERE
	|	Employees.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|	
	|ORDER BY
	|	NestedSelect.LineNumber
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	NestedSelect.Employee,
	|	NestedSelect.Employee.Ind AS Ind,
	|	NestedSelect.LineNumber,
	|	Employees.StructuralUnit,
	|	Employees.Employee AS AdoptedEmployee
	|FROM
	|	(SELECT
	|		TableEmployees.Employee AS Employee,
	|		TableEmployees.LineNumber AS LineNumber,
	|		MAX(Employees.Period) AS DateOfReception,
	|		Employees.Employee AS MainStaff
	|	FROM
	|		InformationRegister.Employees AS Employees
	|			INNER JOIN TableEmployees AS TableEmployees
	|			ON (Employees.Company = &Company)
	|				AND (Employees.Recorder <> &Ref)
	|				AND Employees.Period <= TableEmployees.Period
	|				AND TableEmployees.Employee.Ind <> VALUE(Catalog.Individuals.EmptyRef)
	|				AND Employees.Employee.Ind = TableEmployees.Employee.Ind
	|				AND (TableEmployees.Employee.EmploymentContractType = VALUE(Enum.EmploymentContractTypes.FullTime))
	|				AND (Employees.Employee.EmploymentContractType = VALUE(Enum.EmploymentContractTypes.FullTime))
	|	
	|	GROUP BY
	|		TableEmployees.Employee,
	|		TableEmployees.LineNumber,
	|		Employees.Employee) AS NestedSelect
	|		INNER JOIN InformationRegister.Employees AS Employees
	|		ON (Employees.Company = &Company)
	|			AND NestedSelect.MainStaff = Employees.Employee
	|			AND NestedSelect.DateOfReception = Employees.Period
	|WHERE
	|	Employees.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|	
	|ORDER BY
	|	NestedSelect.LineNumber
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableEmployees.LineNumber,
	|	EmployeesTableTwice.LineNumber AS LineNumberTwo,
	|	EmployeesTableTwice.Employee,
	|	TableEmployees.Employee.Ind AS Ind
	|FROM
	|	
	|		TableEmployees AS TableEmployees
	|			INNER JOIN TableEmployees AS EmployeesTableTwice
	|			ON TableEmployees.Employee.Ind = EmployeesTableTwice.Employee.Ind
	|				AND TableEmployees.Employee.Ind <> VALUE(Catalog.Individuals.EmptyRef)
	|				AND (TableEmployees.Employee.EmploymentContractType = VALUE(Enum.EmploymentContractTypes.FullTime))
	|				AND (EmployeesTableTwice.Employee.EmploymentContractType = VALUE(Enum.EmploymentContractTypes.FullTime))
	|				AND EmployeesTableTwice.LineNumber > TableEmployees.LineNumber
	|	
	|ORDER BY
	|	TableEmployees.LineNumber
	|;
	|	
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TableEmployees.LineNumber,
	|	Employees.Employee
	|FROM
	|	
	|		TableEmployees AS TableEmployees
	|			INNER JOIN InformationRegister.Employees AS Employees
	|			ON TableEmployees.Employee = Employees.Employee
	|				AND (Employees.Recorder <> &Ref)
	|				AND (Employees.Recorder REFS Document.EmploymentContract)
	|				AND (Employees.Period > TableEmployees.Period)
	|	
	|GROUP BY
	|		Employees.Employee,
	|		TableEmployees.LineNumber
	|		
	|ORDER BY
	|	TableEmployees.LineNumber");
	
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	ResultsArray = Query.ExecuteBatch();
	
	// Employee is already accepted on work to reception date.
	If Not ResultsArray[0].IsEmpty() Then
		QueryResultSelection = ResultsArray[0].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en = 'In row #%Number% of the ""Employees"" tabular section, the %Employee% employee already works in the %StructuralUnit% department.'; ru = 'В строке №%Number% табл. части ""Сотрудники"" сотрудник %Employee% уже работает в подразделении %StructuralUnit%.';pl = 'W wierszu nr %Number% sekcji tabelarycznej ""Pracownicy"" pracownik %Employee% pracuje już w dziale %StructuralUnit%.';es_ES = 'En la fila #%Number% de la sección tabular ""Empleados"", el empleado %Employee% ya trabaja en el departamento %StructuralUnit%.';es_CO = 'En la fila #%Number% de la sección tabular ""Empleados"", el empleado %Employee% ya trabaja en el departamento %StructuralUnit%.';tr = '""Çalışanlar"" tablo bölümünün #%Number% satırında, %Employee% çalışan zaten önceden %StructuralUnit% bölümünde çalışıyor.';it = 'Nella riga #%Number% della sezione tabellare ""Dipendenti"", il dipendente %Employee% lavora già nel reparto %StructuralUnit%.';de = 'In der Zeile Nr %Number% des Tabellenabschnitts ""Mitarbeiter"" ist der %Employee%Mitarbeiter bereits in der %StructuralUnit%Abteilung tätig.'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%Employee%", QueryResultSelection.Employee); 
			MessageText = StrReplace(MessageText, "%StructuralUnit%", QueryResultSelection.StructuralUnit);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				QueryResultSelection.LineNumber,
				"Employee",
				Cancel);
		EndDo;
	EndIf;

	// For the Individual of Employee hired to a primary job, another Employee is already hired to a primary job.
	If Not ResultsArray[1].IsEmpty() Then
		QueryResultSelection = ResultsArray[1].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en = 'In row #%Number% of the ""Employees"" tabular section for the %Individual% individual, the %Employee% employee is already hired to a primary place of employment in the %StructuralUnit% department.'; ru = 'В строке №%Number% табл. части ""Сотрудники"" для физического лица %Individual% уже принят на основное место работы сотрудник %Employee% в подразделение %StructuralUnit%.';pl = 'W wierszu nr %Number% sekcji tabelarycznej ""Pracownicy"" dla osoby fizycznej %Individual% na podstawowe miejsce zatrudnienia jest już przyjęty pracownik %Employee% do działu %StructuralUnit%.';es_ES = 'En la fila #%Number% de la sección tabular ""Empleados"" para el particular %Individual%, el empleado %Employee% ya está contratado a una posición primaria de empleo en el departamento %StructuralUnit%.';es_CO = 'En la fila #%Number% de la sección tabular ""Empleados"" para el particular %Individual%, el empleado %Employee% ya está contratado a una posición primaria de empleo en el departamento %StructuralUnit%.';tr = '%Individual% bireyi için ""Çalışanlar"" tablo bölümünün # %Number% satırında, %Employee% çalışan önceden %StructuralUnit% bölümünde temel istihdam yerine kabul edilmiştir.';it = 'Nella riga #%Number% della sezione tabellare ""Dipendenti"" per la persona fisica %Individual%, il dipendente %Employee% è già stato assunto in un primario posto di lavoro nel reparto %StructuralUnit%.';de = 'In der Zeile Nr%Number% des Tabellenabschnitts ""Mitarbeiter"" für die %Individual% natürliche Person ist der %Employee%Mitarbeiter bereits an einen primären Arbeitsplatz in der  %StructuralUnit%Abteilung eingestellt.'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%Employee%", QueryResultSelection.AdoptedEmployee); 
			MessageText = StrReplace(MessageText, "%StructuralUnit%", QueryResultSelection.StructuralUnit); 
			MessageText = StrReplace(MessageText, "%Individual%", QueryResultSelection.Ind);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				QueryResultSelection.LineNumber,
				"Employee",
				Cancel);
		EndDo;
	EndIf;

	// For Individual of the Employee, who is hired to a primary job, another Employee is already specified in this
	// document with a primary job.
	If Not ResultsArray[2].IsEmpty() Then
		QueryResultSelection = ResultsArray[2].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en = 'In row #%NumberDouble% of the ""Employees"" tabular section for the %Individual% individual, the %Employee% employee is rehired to a primary place of employment. Individual is already specified in row #%Number%.'; ru = 'В строке №%NumberDouble% табл. части ""Сотрудники"" для физлица %Individual% повторно принимается на основное место работы сотрудник %Employee%. Физлицо уже указано в строке №%Number%.';pl = 'W wierszu nr %NumberDouble% sekcji tabelarycznej ""Pracownicy"" dla osoby fizycznej %Individual%, pracownik %Employee% jest ponownie zatrudniony w podstawowym miejscu zatrudnienia. Osoba fizyczna jest już określony w wierszu nr %Number%.';es_ES = 'En la fila #%NumberDouble% de la sección tabular ""Empleados"" para el particular %Individual%, el empleado %Employee% se ha vuelto a contratar a una posición primaria de empleo. Particular ya está especificado en la fila #%Number%.';es_CO = 'En la fila #%NumberDouble% de la sección tabular ""Empleados"" para el particular %Individual%, el empleado %Employee% se ha vuelto a contratar a una posición primaria de empleo. Particular ya está especificado en la fila #%Number%.';tr = '%Individual% bireyi için ""Çalışanlar"" tablo bölümünün # %NumberDouble% satırında, %Employee% çalışan temel istihdam yerine yeniden kabul edilmiştir. Birey no. %Number% satırında zaten belirtilmiştir.';it = 'Nella riga #%NumberDouble% della sezione tabellare ""Dipendenti"" per la persona fisica %Individual%, il dipendente %Employee% è riassunto in un primario posto di lavoro. La persona fisica è già specificata nella riga #%Number%.';de = 'In der Zeile Nr.%NumberDouble% des Tabellenabschnitts ""Mitarbeiter"" für die %Individual% natürliche Person wird der %Employee% Mitarbeiter an einen primären Arbeitsplatz zurückgeführt. Die natürliche Person ist bereits in Zeile Nr.%Number% angegeben.'");
			MessageText = StrReplace(MessageText, "%NumberDouble%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%TwinNumber%", QueryResultSelection.LineNumberTwo); 
			MessageText = StrReplace(MessageText, "%Employee%", QueryResultSelection.Employee); 
			MessageText = StrReplace(MessageText, "%Individual%", QueryResultSelection.Ind);
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Employees",
				QueryResultSelection.LineNumberTwo,
				"Employee",
				Cancel);
		EndDo;
	EndIf;

	// The employee is hired repeatedly. 
	If Not ResultsArray[3].IsEmpty() Then
		QueryResultSelection = ResultsArray[3].Select();
		While QueryResultSelection.Next() Do
			MessageText = NStr("en = 'In row #%Number% of the ""Employee"" tabular section: the employee %Employee% worked in the company earlier. To hire the employee again, create a new employee.'; ru = 'В строке №%Number% табл. части ""Сотрудники"": сотрудник %Employee% уже работал в компании. Для повторного приема на работу необходимо создать нового сотрудника.';pl = 'W wierszu nr %Number% sekcji tabelarycznej ""Pracownik"": pracownik %Employee% pracował wcześniej w organizacji. Aby ponownie przyjąć go do pracy, należy utworzyć nowego pracownika.';es_ES = 'En la fila #%Number% de la sección tabular ""Empleado"": el empleado %Employee% ha trabajado en la empresa antes. Para contratar el empleado de nuevo, crear un nuevo empleado.';es_CO = 'En la fila #%Number% de la sección tabular ""Empleado"": el empleado %Employee% ha trabajado en la empresa antes. Para contratar el empleado de nuevo, crear un nuevo empleado.';tr = '""Çalışan"" tablo bölümünün #%Number% satırında: %Employee% çalışanı daha önce iş yerinde çalışmıştır. Çalışanı yeniden kabul etmek için, yeni bir çalışan oluşturun.';it = 'Nella riga №. %Number% della tabella ""Dipendenti"": il dipendente %Employee% ha già lavorato in azienda. Per assumerlo nuovamente, è necessario creare un nuovo dipendente.';de = 'In der Zeile Nr. %Number% des Tabellenabschnitts ""Mitarbeiter"": Der Mitarbeiter %Employee% war früher bei der Firma tätig. Um den Mitarbeiter wieder einzustellen, erstellen Sie einen neuen Mitarbeiter.'");
			MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
			MessageText = StrReplace(MessageText, "%Employee%", QueryResultSelection.Employee);
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

// Controls the staff list.
//
Procedure RunControlStaffSchedule(AdditionalProperties, Cancel) 
	
	If Cancel OR Not Constants.UseHeadcountBudget.Get() Then
		Return;	
	EndIf; 
	
	Query = New Query("
	|SELECT ALLOWED
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
	|			EmploymentContractEmployees.LineNumber AS LineNumber
	|		FROM
	|			Document.EmploymentContract.Employees AS EmploymentContractEmployees
	|				INNER JOIN InformationRegister.HeadcountBudget AS HeadcountBudget
	|				ON EmploymentContractEmployees.StructuralUnit = HeadcountBudget.StructuralUnit
	|					AND EmploymentContractEmployees.Position = HeadcountBudget.Position
	|					AND EmploymentContractEmployees.Period >= HeadcountBudget.Period
	|					AND (HeadcountBudget.Company = &Company)
	|		WHERE
	|			EmploymentContractEmployees.Ref = &Ref
	|		
	|		GROUP BY
	|			HeadcountBudget.Position,
	|			HeadcountBudget.StructuralUnit,
	|			HeadcountBudget.Company,
	|			EmploymentContractEmployees.LineNumber) AS StaffListMaxPeriods
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
	|				EmploymentContractEmployees.LineNumber AS LineNumber,
	|				Employees.Employee AS Employee,
	|				EmploymentContractEmployees.StructuralUnit AS StructuralUnit,
	|				EmploymentContractEmployees.Position AS Position
	|			FROM
	|				Document.EmploymentContract.Employees AS EmploymentContractEmployees
	|					LEFT JOIN InformationRegister.Employees AS Employees
	|					ON EmploymentContractEmployees.Period >= Employees.Period
	|						AND (Employees.Company = &Company)
	|			WHERE
	|				EmploymentContractEmployees.Ref = &Ref
	|			
	|			GROUP BY
	|				Employees.Company,
	|				EmploymentContractEmployees.LineNumber,
	|				Employees.Employee,
	|				EmploymentContractEmployees.StructuralUnit,
	|				EmploymentContractEmployees.Position) AS EmployeesMaximalPeriods
	|				INNER JOIN InformationRegister.Employees AS Employees
	|				ON EmployeesMaximalPeriods.Employee = Employees.Employee
	|					AND EmployeesMaximalPeriods.StructuralUnit = Employees.StructuralUnit
	|					AND EmployeesMaximalPeriods.Position = Employees.Position
	|					AND EmployeesMaximalPeriods.Period = Employees.Period
	|					AND (Employees.Company = &Company)
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

#Region EventsHandlers

// IN handler of document event FillCheckProcessing,
// checked attributes are being copied and reset
// to exclude a standard platform fill check and subsequent check by embedded language tools.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Precheck
	RunPreliminaryControl(Cancel);
	
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
	Documents.EmploymentContract.InitializeDocumentData(Ref, AdditionalProperties);
	
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