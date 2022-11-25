#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	AssignTasks(CommandParameter);
	Notify("EmployeeChanged", CommandParameter);
	NotifyChanged(CommandParameter);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure AssignTasks(ProductionTaskRef)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	UserEmployees.Employee AS Employee
	|FROM
	|	InformationRegister.UserEmployees AS UserEmployees
	|WHERE
	|	UserEmployees.User = &User";
	
	Query.SetParameter("User", Users.CurrentUser());
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		SelectionDetailRecords = QueryResult.Select();
		SelectionDetailRecords.Next();
		
		ProductionTask = ProductionTaskRef.GetObject();
		ProductionTask.Assignee = SelectionDetailRecords.Employee;
		ProductionTask.AdditionalProperties.Insert("DoNotWriteStatus", True);
		
		Try
			
			ProductionTask.Write();
			
		Except
			
			DriveClientServer.ProductionTasksErrorMessage(ProductionTaskRef);
			
		EndTry;
		
	Else
		
		CommonClientServer.MessageToUser(NStr("en = 'Cannot perform the action. You have logged in as a user who is not an employee. Contact the Administrator.'; ru = 'Не удалось выполнить действие. Вы вошли в систему как пользователь, который не является сотрудником. Свяжитесь с администратором.';pl = 'Nie można wykonać działania. Jesteś zalogowany jako użytkownik, który nie jest pracownikiem. Skontaktuj się z Administratorem.';es_ES = 'No se puede realizar la acción. Se ha conectado como un usuario que no es un empleado. Póngase en contacto con el administrador.';es_CO = 'No se puede realizar la acción. Se ha conectado como un usuario que no es un empleado. Póngase en contacto con el administrador.';tr = 'İşlem gerçekleştirilemiyor. Çalışan olarak giriş yapmadınız. Yönetici ile iletişime geçin.';it = 'Impossibile eseguire l''azione. È stato effettuato l''accesso come utente non impiegato. Contattare l''Amministratore.';de = 'Vorgang kann nicht ausgeführt werden. Sie sind als Benutzer und nicht als Mitarbeiter eingeloggt. Kontaktieren Sie bitte Ihren Administrator.'"));
		
	EndIf;
	
EndProcedure

#EndRegion
