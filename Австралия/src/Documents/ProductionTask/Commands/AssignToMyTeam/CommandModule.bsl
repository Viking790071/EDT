#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ArrayTeams = GetUserTeams();
	
	If ArrayTeams.Count() = 0 Then
		CommonClientServer.MessageToUser(NStr("en = 'Cannot perform the action. You are not included in any team. Contact the Administrator.'; ru = 'Не удалось выполнить действие. Вы не входите ни в одну бригаду. Свяжитесь с администратором.';pl = 'Nie można wykonać działania. Nie jesteś członkiem jakiegokolwiek zespołu. Skontaktuj się z Administratorem.';es_ES = 'No puede realizar la acción. No está incluido en ningún equipo. Póngase en contacto con el administrador.';es_CO = 'No puede realizar la acción. No está incluido en ningún equipo. Póngase en contacto con el administrador.';tr = 'İşlem gerçekleştirilemiyor. Hiçbir ekibe dahil değilsiniz. Yönetici ile iletişime geçin.';it = 'Impossibile eseguire l''azione. Non sei incluso in nessun team. Contattare l''Amministratore.';de = 'Vorgang kann nicht ausgeführt werden. Sie gehören zu keinem Team. Kontaktieren Sie bitte Ihren Administrator.'"));
	ElsIf ArrayTeams.Count() = 1 Then
		AssignTasks(CommandParameter, ArrayTeams[0]);
		Notify("EmployeeChanged", CommandParameter);
		NotifyChanged(CommandParameter);
	Else
		FormParameters = New Structure("ArrayTeams",ArrayTeams);
		NotifyDescription = New NotifyDescription("AfterChoiceTeam",ThisObject,CommandParameter);
		OpenForm("Catalog.Teams.Form.ChoiceFormMobileClient",
			FormParameters,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window,
			CommandExecuteParameters.URL,
			NotifyDescription);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AfterChoiceTeam(Result,AddParameters) Export
	
	If ValueIsFilled(Result) Then
		AssignTasks(AddParameters, Result);
		Notify("EmployeeChanged", AddParameters);
		NotifyChanged(AddParameters);
	EndIf;
	
EndProcedure

&AtServer
Function GetUserTeams()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	UserEmployees.Employee AS Employee
	|INTO TT_UserEmployees
	|FROM
	|	InformationRegister.UserEmployees AS UserEmployees
	|WHERE
	|	UserEmployees.User = &User
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TeamsContent.Ref AS Ref
	|FROM
	|	TT_UserEmployees AS TT_UserEmployees
	|		INNER JOIN Catalog.Teams.Content AS TeamsContent
	|		ON TT_UserEmployees.Employee = TeamsContent.Employee";
	
	Query.SetParameter("User", Users.CurrentUser());
	
	QueryResult = Query.Execute().Unload();
	
	Return QueryResult.UnloadColumn("Ref");
	
EndFunction

&AtServer
Procedure AssignTasks(ProductionTaskRef, Assignee)
	
	ProductionTask = ProductionTaskRef.GetObject();
	ProductionTask.Assignee = Assignee;
	ProductionTask.AdditionalProperties.Insert("DoNotWriteStatus", True);
	
	Try
		
		ProductionTask.Write();
		
	Except
		
		Result = False;
		DriveClientServer.ProductionTasksErrorMessage(ProductionTaskRef);
		
	EndTry;

EndProcedure

#EndRegion