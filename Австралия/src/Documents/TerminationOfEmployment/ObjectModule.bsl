#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Controls conflicts.
//
Procedure RunPreliminaryControl(Cancel) 
	
	Query = New Query(
	"SELECT ALLOWED
	|	TerminationOfEmploymentStaff.LineNumber,
	|	TerminationOfEmploymentStaff.Employee,
	|	TerminationOfEmploymentStaff.Period
	|INTO TableEmployees
	|FROM
	|	Document.TerminationOfEmployment.Employees AS TerminationOfEmploymentStaff
	|WHERE
	|	TerminationOfEmploymentStaff.Ref = &Ref
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
	If Not ResultsArray[1].IsEmpty() Then
		QueryResultSelection = ResultsArray[1].Select();
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
	
	// Row duplicates.
	If Not ResultsArray[2].IsEmpty() Then
		QueryResultSelection = ResultsArray[2].Select();
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
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableEmployees.LineNumber AS LineNumber,
	|	TableEmployees.Employee,
	|	MIN(Employees.Period) AS Period
	|FROM
	|	TableEmployees AS TableEmployees
	|		INNER JOIN InformationRegister.Employees AS Employees
	|		ON (Employees.Employee = TableEmployees.Employee)
	|			AND (Employees.Period > TableEmployees.Period)
	|			AND (Employees.Recorder <> &Ref)
	|
	|GROUP BY
	|	TableEmployees.Employee,
	|	TableEmployees.LineNumber
	|
	|ORDER BY
	|	LineNumber");
	
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	
	Result = Query.ExecuteBatch();
	
	// Employee isn't assepted in company on the TerminationOfEmployment date.
	QueryResultSelection = Result[0].Select();
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
	
	// There are register records after TerminationOfEmployment of the employee.
	QueryResultSelection = Result[1].Select();
	While QueryResultSelection.Next() Do
		MessageText = NStr("en = 'In row #%Number% of the ""Employees"" tabular section, there are personnel register records for employee %Employee% within %Period% after TerminationOfEmployment date.'; ru = 'В строке №%Number% табл. части ""Сотрудники"" по сотруднику %Employee% есть кадровые движения в периоде %Period% после даты TerminationOfEmployment.';pl = 'W wierszu nr %Number% sekcji tabelarycznej ""Pracownicy"" istnieją ruchy kadrowe dla pracownika %Employee% w %Period% po dniu TerminationOfEmployment.';es_ES = 'En la fila #%Number% de la sección tabular ""Empleados"", hay grabaciones del registro de empleados para el empleado %Employee% dentro de %Period% después de la fecha de TerminationOfEmployment.';es_CO = 'En la fila #%Number% de la sección tabular ""Empleados"", hay grabaciones del registro de empleados para el empleado %Employee% dentro de %Period% después de la fecha de TerminationOfEmployment.';tr = '""Çalışanlar"" tablo bölümünün %Number% numaralı satırında, %Employee% çalışanı için TerminationOfEmployment tarihinden sonra %Period% döneminde personel kayıtları var.';it = 'Nella riga #%Number% della sezione tabellare ""Dipendenti"", vi sono registrazioni del personale per il dipendente %Employee% in %Period% dopo la data di FineDell''Impiego.';de = 'In der Zeile Nr %Number% des Tabellenabschnitts ""Mitarbeiter"" befinden sich Personalregistereinträge für Mitarbeiter %Employee% innerhalb %Period% nach dem Datum der BeendigungDesArbeitsverhältnisses.'");
		MessageText = StrReplace(MessageText, "%Number%", QueryResultSelection.LineNumber); 
		MessageText = StrReplace(MessageText, "%Employee%", QueryResultSelection.Employee); 
		MessageText = StrReplace(MessageText, "%Period%", Format(QueryResultSelection.Period, "DF=dd.MM.yy"));
		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			"Employees",
			QueryResultSelection.LineNumber,
			"Employee",
			Cancel);
	EndDo; 
			
EndProcedure

#EndRegion

#Region EventsHandlers

// IN handler of document event
// FillCheckProcessing, checked attributes are being copied and reset
// a exclude a standard platform fill check and subsequent check by embedded language tools.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	// Precheck
	RunPreliminaryControl(Cancel);	
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.TerminationOfEmployment.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectEmployees(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCompensationPlan(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	RunControl(AdditionalProperties, Cancel);
	
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