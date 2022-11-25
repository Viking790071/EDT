
#Region EventHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	CurrentObject = ThisObject();
	CurrentObject.ReadSettings();
	CurrentObject.ReadSSLSupportFlags();
	ThisObject(CurrentObject);
	
	RegistrationObject = Parameters.RegistrationObject;
	Details       = "";
	
	If TypeOf(RegistrationObject) = Type("Structure") Then
		RegistrationTable = Parameters.RegistrationTable;
		ObjectAsString = RegistrationTable;
		For Each KeyValue In RegistrationObject Do
			Details = Details + "," + KeyValue.Value;
		EndDo;
		Details = " (" + Mid(Details,2) + ")";
	Else		
		RegistrationTable = "";
		ObjectAsString = RegistrationObject;
	EndIf;
	Title = "Registration " + CurrentObject.RefPresentation(ObjectAsString) + Details;
	
	ReadExchangeNodes();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ExpandAllNodes();
EndProcedure

#EndRegion

#Region ExchangeNodeTreeFormTableItemEventHandlers
//

&AtClient
Procedure ExchangeNodeTreeChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	If Field = Items.ExchangeNodesTreeDescription Or Field = Items.ExchangeNodesTreeCode Then
		OpenOtherObjectEditForm();
		Return;
	ElsIf Field <> Items.ExchangeNodesTreeMessageNumber Then
		Return;
	EndIf;
	
	CurrentData = Items.ExchangeNodesTree.CurrentData;
	Notification = New NotifyDescription("ExchangeNodeTreeChoiceCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Node", CurrentData.Ref);
	
	Tooltip = NStr("ru = 'Номер отправленного'; en = 'Number of sent message'; pl = 'Numer wysłanej wiadomości';es_ES = 'Número de mensaje enviado';es_CO = 'Número de mensaje enviado';tr = 'Gönderilen mesajın numarası';it = 'Numero di messaggio inviato';de = 'Nummer der gesendeten Nachricht'"); 
	ShowInputNumber(Notification, CurrentData.MessageNo, Tooltip);
EndProcedure

&AtClient
Procedure ExchangeNodeTreeMarkOnChange(Item)
	ChangeMark(Items.ExchangeNodesTree.CurrentRow);
EndProcedure

#EndRegion

#Region FormCommandHandlers
//

&AtClient
Procedure RereadNodeTree(Command)
	CurrentNode = CurrentSelectedNode();
	ReadExchangeNodes();
	ExpandAllNodes(CurrentNode);
EndProcedure

&AtClient
Procedure OpenEditFormFromNode(Command)
	OpenOtherObjectEditForm();
EndProcedure

&AtClient
Procedure CheckAllNodes(Command)
	For Each PlanRow In ExchangeNodesTree.GetItems() Do
		PlanRow.Check = True;
		ChangeMark(PlanRow.GetID())
	EndDo;
EndProcedure

&AtClient
Procedure UncheckAllNodes(Command)
	For Each PlanRow In ExchangeNodesTree.GetItems() Do
		PlanRow.Check = False;
		ChangeMark(PlanRow.GetID())
	EndDo;
EndProcedure

&AtClient
Procedure InvertAllNodesChecks(Command)
	For Each PlanRow In ExchangeNodesTree.GetItems() Do
		For Each NodeRow In PlanRow.GetItems() Do
			NodeRow.Check = Not NodeRow.Check;
			ChangeMark(NodeRow.GetID())
		EndDo;
	EndDo;
EndProcedure

&AtClient
Procedure EditRegistration(Command)
	
	QuestionTitle = NStr("ru = 'Подтверждение'; en = 'Confirm operation'; pl = 'Potwierdzenie';es_ES = 'Confirmación';es_CO = 'Confirmación';tr = 'Onay';it = 'Conferma l''operazione';de = 'Bestätigung der Operation'");
	Text = NStr("ru = 'Изменить регистрацию ""%1""
	             |на узлах?'; 
	             |en = 'Change registration ""%1""
	             |on nodes?'; 
	             |pl = 'Zmienić rejestrację ""%1""
	             |na węzłach?';
	             |es_ES = '¿Cambiar el registro ""%1""
	             |en los nodos?';
	             |es_CO = '¿Cambiar el registro ""%1""
	             |en los nodos?';
	             |tr = 'Ünitelerdeki kaydını ""%1""
	             | değiştirmek istiyor musunuz?';
	             |it = 'Modificare la registrazione ""%1""
	             |sui nodi?';
	             |de = 'Die Registrierung ""%1""
	             |auf den Knoten ändern?'");
	
	Text = StrReplace(Text, "%1", RegistrationObject);
	
	Notification = New NotifyDescription("EditRegistrationCompletion", ThisObject);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , ,QuestionTitle);
EndProcedure

&AtClient
Procedure EditRegistrationCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Count = NodeRegistrationEdit(ExchangeNodesTree);
	If Count > 0 Then
		Text = NStr("ru = 'Регистрация %1 была изменена на %2 узлах'; en = 'Registration of %1 was changed for %2 nodes'; pl = 'Rejestracja %1 została zmieniona na %2 węzłach';es_ES = 'Registro de %1 se ha cambiado en los %2 nodos';es_CO = 'Registro de %1 se ha cambiado en los %2 nodos';tr = '%1ünitelerde %2 kayıtları değiştirildi';it = 'La registrazione di %1 è stata modificata sui nodi %2';de = 'Registrierung von %1 wurde auf %2 Knoten geändert'");
		NotificationTitle = NStr("ru = 'Изменение регистрации:'; en = 'Change registration:'; pl = 'Rejestracja zmian:';es_ES = 'Cambiar el registro:';es_CO = 'Cambiar el registro:';tr = 'Kaydı değiştir:';it = 'Cambia registrazione:';de = 'Registrierung ändern:'");
		
		Text = StrReplace(Text, "%1", RegistrationObject);
		Text = StrReplace(Text, "%2", Count);
		
		ShowUserNotification(NotificationTitle,
			GetURL(RegistrationObject),
			Text,
			Items.HiddenPictureInformation32.Picture);
		
		If Parameters.NotifyAboutChanges Then
			Notify("ObjectDataExchangeRegistrationEdit",
				New Structure("RegistrationObject, RegistrationTable", RegistrationObject, RegistrationTable),
				ThisObject);
		EndIf;
	EndIf;
	
	CurrentNode = CurrentSelectedNode();
	ReadExchangeNodes(True);
	ExpandAllNodes(CurrentNode);
EndProcedure

&AtClient
Procedure OpenSettingsForm(Command)
	OpenDataProcessorSettingsForm();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExchangeNodesTreeMessageNumber.Name);

	FIlterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FIlterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExchangeNodesTree.Ref");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExchangeNodesTree.Check");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("Text", NStr("ru = 'ExchangeNodesTreeMessageNumber'; en = 'ExchangeNodesTreeMessageNumber'; pl = 'ExchangeNodesTreeMessageNumber';es_ES = 'TreeNodesExchangeMessageNo';es_CO = 'TreeNodesExchangeMessageNo';tr = 'ExchangeNodesTreeMessageNumber';it = 'ExchangeNodesTreeMessageNumber';de = 'ExchangeNodesTreeMessageNumber'"));
	Item.Appearance.SetParameterValue("Text", NStr("ru = 'Не выгружалось'; en = 'Pending export'; pl = 'Trwa eksport';es_ES = 'Pendiente de exportación';es_CO = 'Pendiente de exportación';tr = 'Dışa aktarım bekleniyor';it = 'Esportazione in attesa';de = 'Export anstehend'"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExchangeNodesTreeCode.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExchangeNodesTreeAutoRecord.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExchangeNodesTreeMessageNumber.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExchangeNodesTree.Ref");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Visible", False);
	Item.Appearance.SetParameterValue("Show", False);

EndProcedure
//

&AtClient
Procedure ExchangeNodeTreeChoiceCompletion(Val Number, Val AdditionalParameters) Export
	If Number = Undefined Then 
		// Canceling input.
		Return;
	EndIf;
	
	EditMessageNumberAtServer(AdditionalParameters.Node, Number, RegistrationObject, RegistrationTable);
	
	CurrentNode = CurrentSelectedNode();
	ReadExchangeNodes(True);
	ExpandAllNodes(CurrentNode);
	
	If Parameters.NotifyAboutChanges Then
		Notify("ObjectDataExchangeRegistrationEdit",
			New Structure("RegistrationObject, RegistrationTable", RegistrationObject, RegistrationTable),
			ThisObject);
	EndIf;
EndProcedure

&AtClient
Function CurrentSelectedNode()
	CurrentData = Items.ExchangeNodesTree.CurrentData;
	If CurrentData = Undefined Then
		Return Undefined;
	EndIf;
	Return New Structure("Description, Ref", CurrentData.Description, CurrentData.Ref);
EndFunction

&AtClient
Procedure OpenDataProcessorSettingsForm()
	CurFormName = GetFormName() + "Form.Settings";
	OpenForm(CurFormName, , ThisObject);
EndProcedure

&AtClient
Procedure OpenOtherObjectEditForm()
	CurFormName = GetFormName() + "Form.Form";
	Data = Items.ExchangeNodesTree.CurrentData;
	If Data <> Undefined AND Data.Ref <> Undefined Then
		CurParameters = New Structure("ExchangeNode, CommandID, RelatedObjects", Data.Ref);
		OpenForm(CurFormName, CurParameters, ThisObject);
	EndIf;
EndProcedure

&AtClient
Procedure ExpandAllNodes(FocusNode = Undefined)
	FoundNode = Undefined;
	
	For Each Row In ExchangeNodesTree.GetItems() Do
		ID = Row.GetID();
		Items.ExchangeNodesTree.Expand(ID, True);
		
		If FocusNode <> Undefined AND FoundNode = Undefined Then
			If Row.Description = FocusNode.Description AND Row.Ref = FocusNode.Ref Then
				FoundNode = ID;
			Else
				For Each Substring In Row.GetItems() Do
					If Substring.Description = FocusNode.Description AND Substring.Ref = FocusNode.Ref Then
						FoundNode = Substring.GetID();
					EndIf;
				EndDo;
			EndIf;
		EndIf;
		
	EndDo;
	
	If FocusNode <> Undefined AND FoundNode <> Undefined Then
		Items.ExchangeNodesTree.CurrentRow = FoundNode;
	EndIf;
	
EndProcedure

&AtServer
Function NodeRegistrationEdit(Val Data)
	CurrentObject = ThisObject();
	NodeCount = 0;
	For Each Row In Data.GetItems() Do
		If Row.Ref <> Undefined Then
			AlreadyRegistered = CurrentObject.ObjectRegisteredForNode(Row.Ref, RegistrationObject, RegistrationTable);
			If Row.Check = 0 AND AlreadyRegistered Then
				Result = CurrentObject.EditRegistrationAtServer(False, True, Row.Ref, RegistrationObject, RegistrationTable);
				NodeCount = NodeCount + Result.Success;
			ElsIf Row.Check = 1 AND (Not AlreadyRegistered) Then
				Result = CurrentObject.EditRegistrationAtServer(True, True, Row.Ref, RegistrationObject, RegistrationTable);
				NodeCount = NodeCount + Result.Success;
			EndIf;
		EndIf;
		NodeCount = NodeCount + NodeRegistrationEdit(Row);
	EndDo;
	Return NodeCount;
EndFunction

&AtServer
Function EditMessageNumberAtServer(Node, MessageNumber, Data, TableName = Undefined)
	Return ThisObject().EditRegistrationAtServer(MessageNumber, True, Node, Data, TableName);
EndFunction

&AtServer
Function ThisObject(CurrentObject = Undefined) 
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function GetFormName(CurrentObject = Undefined)
	Return ThisObject().GetFormName(CurrentObject);
EndFunction

&AtServer
Procedure ChangeMark(Row)
	DataItem = ExchangeNodesTree.FindByID(Row);
	ThisObject().ChangeMark(DataItem);
EndProcedure

&AtServer
Procedure ReadExchangeNodes(OnlyUpdate = False)
	CurrentObject = ThisObject();
	Tree = CurrentObject.GenerateNodeTree(RegistrationObject, RegistrationTable);
	
	If OnlyUpdate Then
		// Updating  fields using the current tree values.
		For Each PlanRow In ExchangeNodesTree.GetItems() Do
			For Each NodeRow In PlanRow.GetItems() Do
				TreeRow = Tree.Rows.Find(NodeRow.Ref, "Ref", True);
				If TreeRow <> Undefined Then
					FillPropertyValues(NodeRow, TreeRow, "Check, InitialMark, MessageNo, NotExported");
				EndIf;
			EndDo;
		EndDo;
	Else
		// Assigning a new value to the ExchangeNodeTree form attribute
		ValueToFormAttribute(Tree, "ExchangeNodesTree");
	EndIf;
	
	For Each PlanRow In ExchangeNodesTree.GetItems() Do
		For Each NodeRow In PlanRow.GetItems() Do
			CurrentObject.ChangeMark(NodeRow);
		EndDo;
	EndDo;
	
EndProcedure

#EndRegion
