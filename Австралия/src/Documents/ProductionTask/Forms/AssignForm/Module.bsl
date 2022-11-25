
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ProductionTasksArray = New Array;
	Parameters.Property("ProductionTasksArray", ProductionTasksArray);
	
	ProductionTasks.LoadValues(ProductionTasksArray);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure TypeIsTeamOnChange(Item)
	
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Assign(Command)
	
	If TypeIsTeam And Not ValueIsFilled(Team) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Specify a team.'; ru = 'Укажите бригаду.';pl = 'Określ zespół.';es_ES = 'Especificar un equipo.';es_CO = 'Especificar un equipo.';tr = 'Takım belirtin.';it = 'Specificare un team.';de = 'Ein Team angeben.'"), , "Team");
		
	ElsIf Not TypeIsTeam And Not ValueIsFilled(Employee) Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Specify an employee.'; ru = 'Укажите сотрудника.';pl = 'Określ pracownika.';es_ES = 'Especificar un empleado.';es_CO = 'Especificar un empleado.';tr = 'Çalışan belirtin.';it = 'Specificare un dipendente.';de = 'Einen Mitarbeiter angeben.'"), , "Employee");
		
	Else
		
		If AssignTasks(ProductionTasks.UnloadValues(), ?(TypeIsTeam, Team, Employee)) Then
			
			For Each TaskLine In ProductionTasks Do
				Notify("EmployeeChanged", TaskLine.Value);
				NotifyChanged(TaskLine.Value);
			EndDo;
			
			Close();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FormManagement()
	
	Items.Team.Visible = TypeIsTeam;
	Items.Employee.Visible = Not TypeIsTeam;
	
EndProcedure

&AtServerNoContext
Function AssignTasks(ProductionTasksArray, Assignee)
	
	Result = True;
	
	For Each ProductionTaskRef In ProductionTasksArray Do
		
		ProductionTask = ProductionTaskRef.GetObject();
		ProductionTask.Assignee = Assignee;
		
		Try
			
			ProductionTask.Write();
			
		Except
			
			Result = False;
			DriveClientServer.ProductionTasksErrorMessage(ProductionTaskRef);
			
		EndTry;
		
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion
