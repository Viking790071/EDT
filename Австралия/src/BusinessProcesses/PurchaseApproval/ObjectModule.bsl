
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
					|ru = '?????????????????? ?????????????????? %1. ?????????? ?????????????? ????????, ???????????????????????? ???????????? ??????????????????????, ???????????????? ???????????????? ??????????????????????,
					|?????????????? ""???????? ?? ?????????????????????? ??????????"" ?? ?????????????????? ???????????????????????? ???? ???????? ""????????, ???????????????????????? ???????????? ??????????????????????"".';
					|pl = 'Nale??y wype??ni?? %1. Aby okre??li?? os??b zatwierdzaj??cych zam??wienie zakupu, otw??rz kart?? Firma,
					|kliknij Role i wykonawcy zada??"" i przydziel u??ytkownika z rol?? ""Osoba zatwierdzaj??ca Zam??wienie zakupu"".';
					|es_ES = 'Es necesario %1. Para especificar los aprobadores de la orden de compra, abra la tarjeta de la empresa,
					| haga clic en ""Funciones y tareas asignadas"" y asigne un usuario con la funci??n ""Aprobador de orden de compra"".';
					|es_CO = 'Es necesario %1. Para especificar los aprobadores de la orden de compra, abra la tarjeta de la empresa,
					| haga clic en ""Funciones y tareas asignadas"" y asigne un usuario con la funci??n ""Aprobador de orden de compra"".';
					|tr = '%1 gerekli. Sat??n alma sipari??i onaylayanlar?? belirtmek i??in i?? yeri kart??n?? a????n,
					|""Roller ve g??revlere atananlar""a t??klay??n ve istedi??iniz kullan??c??y?? ""Sat??n alma sipari??ini onaylayanlar"" rol??ne atay??n.';
					|it = '?? richiesto %1. Per indicare i responsabili approvazione ordine di acquisto, aprire la scheda azienda,
					|cliccare su ""Assegnatari di ruoli e compiti"" e assegnare a un utente il ruolo ""Responsabile approvazione ordine di acquisto"".';
					|de = '%1 ist ein Pflichtfeld. Um Genehmigende der Bestellungen an Lieferanten anzugeben, ??ffnen Sie die Karte der Firma,
					|klicken auf ""Rollen und Bevollm??chtiger"" und bevollm??chtigen Sie einen Benutzer mit der Rolle ""Genehmigende der Bestellung an Lieferanten"".'"),
				Catalogs.PerformerRoles.EmployeeApprovingPurchases);
		Else
			 MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 is required. To specify purchase order approvers, go to 
				|Settings > Purchases / Warehouse, click ""Purchase order approvers"" and add a user to the role.'; 
				|ru = '?????????????????? ?????????????????? %1. ?????????? ?????????????? ????????, ???????????????????????? ???????????? ??????????????????????, ?????????????????? ?? ???????? 
				|?????????????????? > ?????????????? / ??????????, ?????????????? ""????????, ???????????????????????? ???????????? ??????????????????????"" ?? ???????????????? ???????????????????????? ???? ?????? ????????.';
				|pl = 'Nale??y wype??ni?? %1. Aby okre??li?? osob?? zatwierdzaj??c?? zam??wienia zakupu, przejd?? do 
				|Ustawienia > Zakup / Magazyn, kliknij ""Osoby zatwierdzaj??ce zam??wienia zakupu"" i dodaj u??ytkownika do roli.';
				|es_ES = 'Es necesario %1. Para especificar los aprobadores de orden de compra, vaya a 
				|Configuraci??n > Compras / Almac??n, haga clic en ""Aprobadores de orden de compra"" y a??ada un usuario a esa funci??n.';
				|es_CO = 'Es necesario %1. Para especificar los aprobadores de orden de compra, vaya a 
				|Configuraci??n > Compras / Almac??n, haga clic en ""Aprobadores de orden de compra"" y a??ada un usuario a esa funci??n.';
				|tr = '%1 gerekli. Sat??n alma sipari??i onaylayanlar?? belirtmek i??in
				|Ayarlar > Sat??n alma / Ambar b??l??m??nde ""Sat??n alma sipari??ini onaylayanlar""a t??klay??p bu role kullan??c?? ekleyin.';
				|it = '?? richiesto %1. Per indicare i responsabili approvazione ordine di acquisto, andare in 
				|Impostazioni > Acquisti / Magazzino, cliccare ""Responsabili approvazione ordine acquisto"" e aggiungere un utente al ruolo.';
				|de = '%1 ist ein Pflichtfeld. Um Genehmigende der Bestellungen an Lieferanten anzugeben, gehen Sie zu 
				|Einstellungen > Eink??ufe/ Lager, klicken auf ""Genehmigende der Bestellung an Lieferanten"" und f??gen Sie einen Benutzer der Rolle hinzu.'"),
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
			NStr("en = '%1. Please post the document first.'; ru = '%1. ?????????????? ?????????????????? ????????????????.';pl = '%1. Najpierw dekretuj dokument.';es_ES = '%1. Por favor, publique primero el documento.';es_CO = '%1. Por favor, publique primero el documento.';tr = '%1. L??tfen ??nce belgeyi kaydedin.';it = '%1. Pubblicare prima il documento.';de = '%1. Bitte buchen Sie das Dokument zuerst.'"),
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
				NStr("en = 'The previous approval request has been completed.'; ru = '???????????????????? ???????????? ???? ?????????????????????? ????????????????.';pl = 'Poprzednie zapytanie o zatwierdzenie zosta??o zako??czone.';es_ES = 'La solicitud de aprobaci??n anterior ha sido finalizada.';es_CO = 'La solicitud de aprobaci??n anterior ha sido finalizada.';tr = '??nceki onay talebi tamamland??.';it = 'La richiesta di approvazione precedente ?? stata completata.';de = 'Die fr??here Genehmigungsabfrage wurde abgeschlossen.'"),
				PurchaseOrder);
			CommonClientServer.MessageToUser(MessageText);
			
		Else
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 already has incomplete business process.'; ru = '?? %1 ?????? ???????? ?????????????????????????? ????????????-??????????????.';pl = '%1 ju?? ma niekompletny proces biznesowy.';es_ES = '%1 cuenta ya con un proceso de negocio incompleto.';es_CO = '%1 cuenta ya con un proceso de negocio incompleto.';tr = '%1 zaten tamamlanmam???? i?? s??reci mevcut.';it = '%1 ha gi?? un processo aziendale incompleto.';de = '%1 hat bereits einen nicht abgeschlossenen Businessvorgang.'"),
				PurchaseOrder);
			Raise MessageText;
			
		EndIf;	
			
	EndIf;

EndProcedure

#EndRegion

#EndRegion

#EndIf