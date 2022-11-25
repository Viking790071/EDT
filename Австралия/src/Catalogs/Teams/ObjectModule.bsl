#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	TeamEmployees = Content.Unload();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TeamEmployees.Employee AS Employee
	|INTO TemporaryTeamTable
	|FROM
	|	&TeamEmployees AS TeamEmployees
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTeamTable.Employee AS Employee,
	|	COUNT(TemporaryTeamTable.Employee) AS EmployeeCount
	|INTO TemporaryEmployeeCount
	|FROM
	|	TemporaryTeamTable AS TemporaryTeamTable
	|		INNER JOIN TemporaryTeamTable AS TemporaryTeamTable1
	|		ON TemporaryTeamTable.Employee = TemporaryTeamTable1.Employee
	|
	|GROUP BY
	|	TemporaryTeamTable.Employee
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryEmployeeCount.Employee AS Employee
	|FROM
	|	TemporaryEmployeeCount AS TemporaryEmployeeCount
	|WHERE
	|	TemporaryEmployeeCount.EmployeeCount > 1";
	
	Query.SetParameter("TeamEmployees", TeamEmployees);
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		
		EmployeeArray = QueryResult.Unload().UnloadColumn("Employee");
		
		StringOfEmployees = StrConcat(EmployeeArray, ", ");
		
		If EmployeeArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The employee %1 is duplicated.'; ru = 'Для сотрудника %1 существует дублирующая запись.';pl = 'Pracownik %1 jest duplikowany.';es_ES = 'El empleado %1 se ha duplicado.';es_CO = 'El empleado %1 se ha duplicado.';tr = 'Çalışan %1 çoğaltılmış.';it = 'Il dipendente %1 è duplicato.';de = 'Der Mitarbeiter %1 ist dupliziert.'"),
				StringOfEmployees);
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The following employees are duplicated: %1.'; ru = 'Следующие сотрудники имеют дублирующие записи: %1.';pl = 'Następujący pracownicy są duplikowani: %1.';es_ES = 'Los siguientes empleados se han duplicado: %1.';es_CO = 'Los siguientes empleados se han duplicado: %1.';tr = 'Aşağıdaki çalışanlar çoğaltılmıştır: %1.';it = 'I seguenti dipendenti sono duplicati: %1.';de = 'Folgende Mitarbeiter sind doppelt vorhanden: %1.'"),
				StringOfEmployees);
		EndIf;
		
		CommonClientServer.MessageToUser(MessageText,,,,Cancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
