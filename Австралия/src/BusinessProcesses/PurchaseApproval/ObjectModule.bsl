
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.AccessManagement

// See AccessManagement.FillAccessValuesSets. 
//
// Parameters:
//   Table - ValueTable - see AccessManagement.AccessValuesSetsTable. 
//
Procedure FillAccessValuesSets(Table) Export
	
	BusinessProcessesAndTasksOverridable.OnFillingAccessValuesSets(ThisObject, Table);
	
	If Table.Count() > 0 Then
		Return;
	EndIf;
	
	FillDefaultAccessValuesSets(Table);
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	CheckGeneration(FillingData);
	
	If IsNew() Then
		Author = Users.AuthorizedUser();
	EndIf;
	
	FillBusinessProcessGeneratedOnPurchaseOrder(FillingData);

EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ValueIsFilled(ApprovalUntil) And ApprovalUntil < BegOfDay(Date) Then
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en='Approval date must be not less than the business process date %1';'"),
			Format(Date, "DLF=D"));
		
		CommonClientServer.MessageToUser(
			ErrorText,
			ThisObject,
			"ApprovalUntil",
			,
			Cancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

#Region InitializationAndFilling

Procedure FillDefaultAccessValuesSets(Table)
	
	// Default restriction logic for
	// - Reading:    Author OR Performer (taking into account addressing) OR Supervisor (taking into account addressing).
	// - Changes: Author.
	
	// If the subject is not specified (the business process is not based on another subject), then the subject is not involved in the restriction logic.
	
	// Read, Update: set #1.
	Row = Table.Add();
	Row.SetNumber	= 1;
	Row.Read		= True;
	Row.Update		= True;
	Row.AccessValue	= Author;
	
EndProcedure

Procedure FillBusinessProcessGeneratedOnPurchaseOrder(Basis)

	If TypeOf(Basis) = Type("Structure")
		And Basis.Property("Subject") Then
		BasisDocument = Basis.Subject;
	Else
		BasisDocument = Basis;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	PurchaseOrder.Ref AS Subject,
	|	PurchaseOrder.ApprovalDate AS ApprovalUntil,
	|	PurchaseOrder.OrderState AS OrderState,
	|	VALUE(Enum.TaskImportanceOptions.Normal) AS Importance,
	|	PurchaseOrder.Company AS Company
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	PurchaseOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", BasisDocument);
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	Selection.Next();	
	
	FillPropertyValues(ThisObject, Selection);
	
	If Constants.UseSeparateApproversForCompanies.Get() Then
		MainAddressingObject = Selection.Company;	
	EndIf;
	
EndProcedure

#EndRegion

#Region Others

Function CreateTask(Val BusinessProcessRoutePoint)
	
	Task = Tasks.PerformerTask.CreateTask();
	
	Task.Date						= CurrentDate();
	Task.Author						= Author;
	Task.Description				= BusinessProcessRoutePoint.TaskDescription;
	Task.Details					= Description;
	Task.Topic						= Subject;
	Task.Importance					= Importance;
	Task.PerformerRole				= BusinessProcessRoutePoint.PerformerRole;
	Task.MainAddressingObject		= MainAddressingObject;
	Task.BusinessProcess			= Ref;
	Task.DueDate					= ApprovalUntil;
	Task.RoutePoint					= BusinessProcessRoutePoint;
	
	Return Task;
	
EndFunction

Procedure ApproveBeforeCreateTasks(BusinessProcessRoutePoint, TasksBeingFormed, StandardProcessing)
	
	StandardProcessing = False;
	
	Task = CreateTask(BusinessProcessRoutePoint);
	TasksBeingFormed.Add(Task);
	Documents.PurchaseOrder.ChangePurchaseOrderApprovalStatus(Subject, Ref);
	
EndProcedure

Procedure ViewResultBeforeCreateTasks(BusinessProcessRoutePoint, TasksBeingFormed, StandardProcessing)
	
	StandardProcessing = False;
	
	Task = CreateTask(BusinessProcessRoutePoint);
	Task.Performer = Author;
	TasksBeingFormed.Add(Task);
		
EndProcedure

Procedure CompletionOnComplete(BusinessProcessRoutePoint, Cancel)
	CompletedOn = CurrentSessionDate();
EndProcedure

Procedure ApproveOnExecute(BusinessProcessRoutePoint, Task, Cancel)
	Documents.PurchaseOrder.ChangePurchaseOrderApprovalStatus(Subject, Ref);
EndProcedure

Procedure GetResultConditionCheck(BusinessProcessRoutePoint, Result)
	
	Result	= DriveReUse.GetValueByDefaultUser(Author, "NotifyAuthorOfPurchaseApprovalResult");
	
EndProcedure

Procedure StartBeforeStart(BusinessProcessRoutePoint, Cancel)
	
	StartDate = CurrentSessionDate();
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	TaskPerformers.Performer AS Performer
	|FROM
	|	InformationRegister.TaskPerformers AS TaskPerformers
	|WHERE
	|	TaskPerformers.PerformerRole = VALUE(Catalog.PerformerRoles.EmployeeApprovingPurchases)
	|	AND TaskPerformers.MainAddressingObject = &MainAddressingObject";
	
	Query.SetParameter("MainAddressingObject", MainAddressingObject);
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		
		If ValueIsFilled(MainAddressingObject) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 is required. To specify purchase order approvers, open the company card,
					|click ""Roles and tasks assignees"" and assign a user with the ""Purchase order approver"" role.'; 
					|ru = 'Требуется заполнить %1. Чтобы указать лица, утверждающие заказы поставщикам, откройте карточку организации,
					|нажмите ""Роли и исполнители задач"" и назначьте пользователя на роль ""Лицо, утверждающее заказы поставщикам"".';
					|pl = 'Należy wypełnić %1. Aby określić osób zatwierdzających zamówienie zakupu, otwórz kartę Firma,
					|kliknij Role i wykonawcy zadań"" i przydziel użytkownika z rolą ""Osoba zatwierdzająca Zamówienie zakupu"".';
					|es_ES = 'Es necesario %1. Para especificar los aprobadores de la orden de compra, abra la tarjeta de la empresa,
					| haga clic en ""Funciones y tareas asignadas"" y asigne un usuario con la función ""Aprobador de orden de compra"".';
					|es_CO = 'Es necesario %1. Para especificar los aprobadores de la orden de compra, abra la tarjeta de la empresa,
					| haga clic en ""Funciones y tareas asignadas"" y asigne un usuario con la función ""Aprobador de orden de compra"".';
					|tr = '%1 gerekli. Satın alma siparişi onaylayanları belirtmek için iş yeri kartını açın,
					|""Roller ve görevlere atananlar""a tıklayın ve istediğiniz kullanıcıyı ""Satın alma siparişini onaylayanlar"" rolüne atayın.';
					|it = 'È richiesto %1. Per indicare i responsabili approvazione ordine di acquisto, aprire la scheda azienda,
					|cliccare su ""Assegnatari di ruoli e compiti"" e assegnare a un utente il ruolo ""Responsabile approvazione ordine di acquisto"".';
					|de = '%1 ist ein Pflichtfeld. Um Genehmigende der Bestellungen an Lieferanten anzugeben, öffnen Sie die Karte der Firma,
					|klicken auf ""Rollen und Bevollmächtiger"" und bevollmächtigen Sie einen Benutzer mit der Rolle ""Genehmigende der Bestellung an Lieferanten"".'"),
				Catalogs.PerformerRoles.EmployeeApprovingPurchases);
		Else
			 MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 is required. To specify purchase order approvers, go to 
				|Settings > Purchases / Warehouse, click ""Purchase order approvers"" and add a user to the role.'; 
				|ru = 'Требуется заполнить %1. Чтобы указать лица, утверждающие заказы поставщикам, перейдите в меню 
				|Настройки > Закупки / Склад, нажмите ""Лица, утверждающие заказы поставщикам"" и добавьте пользователя на эту роль.';
				|pl = 'Należy wypełnić %1. Aby określić osobę zatwierdzającą zamówienia zakupu, przejdź do 
				|Ustawienia > Zakup / Magazyn, kliknij ""Osoby zatwierdzające zamówienia zakupu"" i dodaj użytkownika do roli.';
				|es_ES = 'Es necesario %1. Para especificar los aprobadores de orden de compra, vaya a 
				|Configuración > Compras / Almacén, haga clic en ""Aprobadores de orden de compra"" y añada un usuario a esa función.';
				|es_CO = 'Es necesario %1. Para especificar los aprobadores de orden de compra, vaya a 
				|Configuración > Compras / Almacén, haga clic en ""Aprobadores de orden de compra"" y añada un usuario a esa función.';
				|tr = '%1 gerekli. Satın alma siparişi onaylayanları belirtmek için
				|Ayarlar > Satın alma / Ambar bölümünde ""Satın alma siparişini onaylayanlar""a tıklayıp bu role kullanıcı ekleyin.';
				|it = 'È richiesto %1. Per indicare i responsabili approvazione ordine di acquisto, andare in 
				|Impostazioni > Acquisti / Magazzino, cliccare ""Responsabili approvazione ordine acquisto"" e aggiungere un utente al ruolo.';
				|de = '%1 ist ein Pflichtfeld. Um Genehmigende der Bestellungen an Lieferanten anzugeben, gehen Sie zu 
				|Einstellungen > Einkäufe/ Lager, klicken auf ""Genehmigende der Bestellung an Lieferanten"" und fügen Sie einen Benutzer der Rolle hinzu.'"),
				Catalogs.PerformerRoles.EmployeeApprovingPurchases);
		EndIf;
		
		CommonClientServer.MessageToUser(MessageText);
		Cancel = True;
		
	EndIf;

EndProcedure

Procedure CheckGeneration(FillingData)
	
	If TypeOf(FillingData) = Type("Structure")
		And FillingData.Property("Subject") Then
		PurchaseOrder = FillingData.Subject;
	Else
		PurchaseOrder = FillingData;
	EndIf;
	
	If Not PurchaseOrder.Posted Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1. Please post the document first.'; ru = '%1. Сначала проведите документ.';pl = '%1. Najpierw dekretuj dokument.';es_ES = '%1. Por favor, publique primero el documento.';es_CO = '%1. Por favor, publique primero el documento.';tr = '%1. Lütfen önce belgeyi kaydedin.';it = '%1. Pubblicare prima il documento.';de = '%1. Bitte buchen Sie das Dokument zuerst.'"),
			PurchaseOrder);
		Raise MessageText;
		
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	PurchaseApproval.Ref AS Ref
	|FROM
	|	BusinessProcess.PurchaseApproval AS PurchaseApproval
	|WHERE
	|	PurchaseApproval.Subject = &Subject
	|	AND NOT PurchaseApproval.Completed";
	
	Query.SetParameter("Subject", PurchaseOrder);
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		If Common.ObjectAttributeValue(PurchaseOrder, "ApprovalStatus") = Enums.ApprovalStatuses.Rejected Then
			
			Selection = QueryResult.Select();
			If Selection.Next() Then
				BusinessProcessObject = Selection.Ref.GetObject();
				BusinessProcessObject.Completed = True;
				BusinessProcessObject.Write();
			EndIf;
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The previous approval request has been completed.'; ru = 'Предыдущий запрос на утверждение завершен.';pl = 'Poprzednie zapytanie o zatwierdzenie zostało zakończone.';es_ES = 'La solicitud de aprobación anterior ha sido finalizada.';es_CO = 'La solicitud de aprobación anterior ha sido finalizada.';tr = 'Önceki onay talebi tamamlandı.';it = 'La richiesta di approvazione precedente è stata completata.';de = 'Die frühere Genehmigungsabfrage wurde abgeschlossen.'"),
				PurchaseOrder);
			CommonClientServer.MessageToUser(MessageText);
			
		Else
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 already has incomplete business process.'; ru = 'У %1 уже есть незавершенный бизнес-процесс.';pl = '%1 już ma niekompletny proces biznesowy.';es_ES = '%1 cuenta ya con un proceso de negocio incompleto.';es_CO = '%1 cuenta ya con un proceso de negocio incompleto.';tr = '%1 zaten tamamlanmamış iş süreci mevcut.';it = '%1 ha già un processo aziendale incompleto.';de = '%1 hat bereits einen nicht abgeschlossenen Businessvorgang.'"),
				PurchaseOrder);
			Raise MessageText;
			
		EndIf;	
			
	EndIf;

EndProcedure

#EndRegion

#EndRegion

#EndIf