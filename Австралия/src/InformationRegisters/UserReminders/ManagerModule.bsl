#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	IsAuthorizedUser(User)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region LibrariesHandlers

#Region ToDoList

// StandardSubsystems.ToDoList

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	If Not AccessRight("Edit", Metadata.InformationRegisters.UserReminders) Then
		Return;
	EndIf;
	
	DocumentsCount = DocumentsCount();
	DocumentsID = "UserReminders";
	
	// My reminders
	ToDo				= ToDoList.Add();
	ToDo.ID				= DocumentsID;
	ToDo.HasUserTasks	= (DocumentsCount.MyRemindersTotalReminders > 0);
	ToDo.Presentation	= NStr("en = 'My reminders'; ru = 'Мои напоминания';pl = 'Moje przypomnienia';es_ES = 'Mis recordatorios';es_CO = 'Mis recordatorios';tr = 'Hatırlatıcılarım';it = 'I miei promemoria';de = 'Meine Wiedervorlagen'");
	ToDo.Owner			= Metadata.Subsystems.Enterprise;
	
	// All reminders
	ToDo				= ToDoList.Add();
	ToDo.ID				= "MyRemindersTotalReminders";
	ToDo.HasUserTasks	= (DocumentsCount.MyRemindersTotalReminders > 0);
	ToDo.Presentation	= NStr("en = 'All reminders'; ru = 'Все напоминания';pl = 'Wszystkie przypomnienia';es_ES = 'Todos los recordatorios';es_CO = 'Todos los recordatorios';tr = 'Tüm hatırlatıcılar';it = 'Tutti i promemoria';de = 'Alle Mahnungen'");
	ToDo.Count			= DocumentsCount.MyRemindersTotalReminders;
	ToDo.Form			= "InformationRegister.UserReminders.Form.MyReminders";
	ToDo.Owner			= DocumentsID;
	
EndProcedure

// End StandardSubsystems.ToDoList

#EndRegion

#EndRegion

#Region Private

#Region ToDoList

&AtServer
Function DocumentsCount()
	
	Result = New Structure;
	Result.Insert("MyRemindersTotalReminders",	0);
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	COUNT(*) AS MyRemindersTotalReminders
	|FROM
	|	InformationRegister.UserReminders AS InformationRegisterUserReminders
	|WHERE
	|	InformationRegisterUserReminders.User = &User";
	
	Query.SetParameter("User", Users.AuthorizedUser());
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		FillPropertyValues(Result, SelectionDetailRecords);
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion

#EndIf
