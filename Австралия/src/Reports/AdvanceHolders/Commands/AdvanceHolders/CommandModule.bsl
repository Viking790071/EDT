&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Filter = New Structure;
	Filter.Insert("Employee", GetEmployeeArray(CommandParameter));
	
	OpenForm("Report.AdvanceHolders.Form",
		New Structure("Filter, GenerateOnOpen", Filter, True),
		,
		"Employee=" + CommandParameter,
		CommandExecuteParameters.Window);
	
EndProcedure

&AtServer
Function GetEmployeeArray(CommandParameter)

	EmployeeArray = New Array;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		For Each Document In CommandParameter Do
			If TypeOf(Document) = Type("DocumentRef.ExpenseReport") Then
				Employee = Common.ObjectAttributeValue(Document, "Employee");
				EmployeeArray.Add(Employee);
			Else
				Employee = Common.ObjectAttributeValue(Document, "AdvanceHolder");
				EmployeeArray.Add(Employee);
			EndIf;
		EndDo;
	EndIf;
	
	Return EmployeeArray;

EndFunction
