
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	DataSeparationEnabled = Common.DataSeparationEnabled();
	If NOT Users.IsFullUser(, Not DataSeparationEnabled) Then
		Raise NStr("ru = 'Недостаточно прав для открытия списка пользователей информационной базы.'; en = 'Insufficient rights to access the infobase user list.'; pl = 'Niewystarczające uprawnienia do otwierania listy użytkowników bazy informacyjnej.';es_ES = 'Insuficientes derechos para abrir la lista de usuarios de la infobase.';es_CO = 'Insuficientes derechos para abrir la lista de usuarios de la infobase.';tr = 'Veritabanı kullanıcı listesini açmak için yetersiz haklar.';it = 'Permessi insufficienti per accedere all''elenco utenti infobase.';de = 'Unzureichende Rechte zum Öffnen der Infobase-Benutzerliste.'");
	EndIf;
	
	Users.FindAmbiguousIBUsers(Undefined);
	
	UsersTypes.Add(Type("CatalogRef.Users"));
	If GetFunctionalOption("UseExternalUsers") Then
		UsersTypes.Add(Type("CatalogRef.ExternalUsers"));
	EndIf;
	
	ShowOnlyItemsProcessedInDesigner = True;
	
	FillIBUsers();
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
		Items.Move(Items.CommandBar, Items.CommandBarForm);
		
		CommonClientServer.SetFormItemProperty(Items, "CommandBar", "Kind", FormGroupType.ButtonGroup);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "IBUserAdded"
	 OR EventName = "IBUserChanged"
	 OR EventName = "IBUserDeleted"
	 OR EventName = "MappingToNonExistingIBUserCleared" Then
		
		FillIBUsers();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ShowOnlyItemsProcessedInDesignerOnChange(Item)
	
	FillIBUsers();
	
EndProcedure

#EndRegion

#Region IBUsersFormTableItemsEventHandlers

&AtClient
Procedure IBUsersOnActivateRow(Item)
	
	CurrentData = Items.IBUsers.CurrentData;
	
	If CurrentData = Undefined Then
		CanDelete     = False;
		CanMap = False;
		CanGoToUser  = False;
		CanCancelMapping = False;
	Else
		CanDelete     = Not ValueIsFilled(CurrentData.Ref);
		CanMap = Not ValueIsFilled(CurrentData.Ref);
		CanGoToUser  = ValueIsFilled(CurrentData.Ref);
		CanCancelMapping = ValueIsFilled(CurrentData.Ref);
	EndIf;
	
	Items.IBUsersDelete.Enabled = CanDelete;
	
	Items.IBUsersGoToUser.Enabled                = CanGoToUser;
	Items.IBUsersContextMenuGoToUser.Enabled = CanGoToUser;
	
	Items.IBUsersMap.Enabled       = CanMap;
	Items.IBUsersMapToNewUser.Enabled = CanMap;
	
	Items.IBUsersCancelMapping.Enabled = CanCancelMapping;
	
EndProcedure

&AtClient
Procedure IBUsersBeforeDelete(Item, Cancel)
	
	Cancel = True;
	
	If Not ValueIsFilled(Items.IBUsers.CurrentData.Ref) Then
		DeleteCurrentIBUser(True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Update(Command)
	
	FillIBUsers();
	
EndProcedure

&AtClient
Procedure Map(Command)
	
	MapIBUser();
	
EndProcedure

&AtClient
Procedure MapToNewUser(Command)
	
	MapIBUser(True);
	
EndProcedure

&AtClient
Procedure GoToUser(Command)
	
	OpenUserByRef();
	
EndProcedure

&AtClient
Procedure CancelMapping(Command)
	
	If Items.IBUsers.CurrentData = Undefined Then
		Return;
	EndIf;
	
	Buttons = New ValueList;
	Buttons.Add("CancelMapping", NStr("ru = 'Отменить сопоставление'; en = 'Clear mapping'; pl = 'Wyczyść mapowanie';es_ES = 'Eliminar el mapeo';es_CO = 'Eliminar el mapeo';tr = 'Eşleştirmeyi temizle';it = 'Cancellare mappatura';de = 'Mapping abbrechen'"));
	Buttons.Add("KeepMapping", NStr("ru = 'Оставить сопоставление'; en = 'Keep mapping'; pl = 'Zostawić mapowanie';es_ES = 'Abandonar el mapeo';es_CO = 'Abandonar el mapeo';tr = 'Eşleştirmeyi bırak';it = 'Mantieni la mappatura';de = 'Mapping belassen'"));
	
	ShowQueryBox(
		New NotifyDescription("CancelMappingFollowUp", ThisObject),
		NStr("ru = 'Отменить сопоставление пользователя информационной базы с пользователем в справочнике?
		           |
		           |Отмена сопоставления требуется крайне редко, только если сопоставление было выполнено некорректно, например,
		           |при обновлении информационной базы. Не рекомендуется отменять сопоставление по другим причинам.'; 
		           |en = 'Do you want to clear the mapping between the infobase user and the application user?
		           |
		           |It is required in rare cases when a mapping is incorrect
		           |(for example, an infobase update might generate an incorrect mapping). It is recommended that you never clear correct mappings.'; 
		           |pl = 'Czy chcesz oczyścić mapowanie między użytkownikiem bazy informacyjnej i użytkownikiem aplikacji?
		           |
		           |W rzadkich przypadkach wymagane jest mapowanie
		           |(na przykład, aktualizacja bazy informacyjnej może wygenerować nieprawidłowe mapowanie). Dlatego nie zaleca się oczyszczać poprawnego mapowania.';
		           |es_ES = 'Cancelar el mapeo del usuario de la infobase con el usuario en el catálogo.
		           |
		           |Se requiere muy raramemente cancelar el mapeo, solo si el mapeo
		           |se ha finalizado de forma incorrecta, por ejemplo, al actualizar una infobase, así que no se recomienda cancelar el mapeo por cualquier otro motivo.';
		           |es_CO = 'Cancelar el mapeo del usuario de la infobase con el usuario en el catálogo.
		           |
		           |Se requiere muy raramemente cancelar el mapeo, solo si el mapeo
		           |se ha finalizado de forma incorrecta, por ejemplo, al actualizar una infobase, así que no se recomienda cancelar el mapeo por cualquier otro motivo.';
		           |tr = 'Veritabanı kullanıcısını katalogdaki kullanıcıyla eşleştirmeyi iptal edin. 
		           |
		           |Eşleştirme iptali çok nadiren gereklidir, ancak eşleştirme 
		           |yanlış bir şekilde tamamlandığında, örneğin bir veritabanın güncellenmesi durumunda, başka herhangi bir nedenden dolayı eşleştirmenin iptal edilmesi tavsiye edilmez.';
		           |it = 'Volete annullare la mappatura tra l''utente infobase e l''utente dell''applicazione?
		           |
		           |E'' richiesto in rari casi quando la mappatura non è corretta
		           |(per esempio, un aggiornamento infabase potrebbe creare una mappatura non corretta). Si raccomanda di non annullare mai mappature corrette.';
		           |de = 'Möchten Sie Mapping des infobase-Benutzers mit dem Benutzer der Anwendung abbrechen?
		           |
		           |Das Löschen von Mapping ist sehr selten erforderlich, nur wenn Mapping
		           |nicht korrekt ausgeführt wurde, zum Beispiel beim Aktualisieren einer Infobase, daher ist es nicht empfehlenswert, Mapping aus einem anderen Grund abzubrechen.'"),
		Buttons,
		,
		"KeepMapping");
		
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FullName.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Name.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.StandardAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSUser.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OpenIDAuthentication.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("IBUsers.AddedInDesigner");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.SpecialTextColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FullName.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Name.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.StandardAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSUser.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OpenIDAuthentication.Name);

	FIlterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FIlterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("IBUsers.ModifiedInDesigner");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("IBUsers.DeletedInDesigner");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Name.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.StandardAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSAuthentication.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OpenIDAuthentication.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("IBUsers.DeletedInDesigner");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Text", NStr("ru = '<Нет данных>'; en = '<No data>'; pl = '<Brak danych>';es_ES = '<No hay datos>';es_CO = '<No data>';tr = '<Veri yok>';it = '<Nessun dato>';de = '<Keine Daten>'"));
	Item.Appearance.SetParameterValue("Format", "L=ru; BF=Нет; BT=Да");

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.OSAuthentication.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("IBUsers.OSUser");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Format", "L=ru; BF=; BT=Да");

EndProcedure

&AtServer
Procedure FillIBUsers()
	
	EmptyUniqueID = New UUID("00000000-0000-0000-0000-000000000000");
	
	If Items.IBUsers.CurrentRow <> Undefined Then
		Row = IBUsers.FindByID(Items.IBUsers.CurrentRow);
	Else
		Row = Undefined;
	EndIf;
	
	IBUserCurrentID =
		?(Row = Undefined, EmptyUniqueID, Row.IBUserID);
	
	IBUsers.Clear();
	NonExistingIBUsersIDs.Clear();
	NonExistingIBUsersIDs.Add(EmptyUniqueID);
	
	Query = New Query;
	Query.SetParameter("EmptyUniqueID", EmptyUniqueID);
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref,
	|	Users.Description AS FullName,
	|	Users.IBUserID,
	|	FALSE AS IsExternalUser
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.IBUserID <> &EmptyUniqueID
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.Ref,
	|	ExternalUsers.Description,
	|	ExternalUsers.IBUserID,
	|	TRUE
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.IBUserID <> &EmptyUniqueID";
	
	DataExported = Query.Execute().Unload();
	DataExported.Indexes.Add("IBUserID");
	DataExported.Columns.Add("Mapped", New TypeDescription("Boolean"));
	
	AllIBUsers = InfoBaseUsers.GetUsers();
	
	For Each InfobaseUser In AllIBUsers Do
		
		ModifiedInDesigner = False;
		Row = DataExported.Find(InfobaseUser.UUID, "IBUserID");
		PropertiesIBUser = Users.IBUserProperies(InfobaseUser.UUID);
		If PropertiesIBUser = Undefined Then
			PropertiesIBUser = Users.NewIBUserDetails();
		EndIf;
		
		If Row <> Undefined Then
			Row.Mapped = True;
			If Row.FullName <> PropertiesIBUser.FullName Then
				ModifiedInDesigner = True;
			EndIf;
		EndIf;
		
		If ShowOnlyItemsProcessedInDesigner
		   AND Row <> Undefined
		   AND Not ModifiedInDesigner Then
			
			Continue;
		EndIf;
		
		NewRow = IBUsers.Add();
		NewRow.FullName                   = PropertiesIBUser.FullName;
		NewRow.Name                         = PropertiesIBUser.Name;
		NewRow.StandardAuthentication   = PropertiesIBUser.StandardAuthentication;
		NewRow.OSAuthentication            = PropertiesIBUser.OSAuthentication;
		NewRow.IBUserID = PropertiesIBUser.UUID;
		NewRow.OSUser              = PropertiesIBUser.OSUser;
		NewRow.OpenIDAuthentication        = PropertiesIBUser.OpenIDAuthentication;
		
		If Row = Undefined Then
			// The infobase user is not in the catalog.
			NewRow.AddedInDesigner = True;
		Else
			NewRow.Ref                           = Row.Ref;
			NewRow.MappedToExternalUser = Row.IsExternalUser;
			
			NewRow.ModifiedInDesigner = ModifiedInDesigner;
		EndIf;
		
	EndDo;
	
	Filter = New Structure("Mapped", False);
	Rows = DataExported.FindRows(Filter);
	For each Row In Rows Do
		NewRow = IBUsers.Add();
		NewRow.FullName                        = Row.FullName;
		NewRow.Ref                           = Row.Ref;
		NewRow.MappedToExternalUser = Row.IsExternalUser;
		NewRow.DeletedInDesigner             = True;
		NonExistingIBUsersIDs.Add(Row.IBUserID);
	EndDo;
	
	Filter = New Structure("IBUserID", IBUserCurrentID);
	Rows = IBUsers.FindRows(Filter);
	If Rows.Count() > 0 Then
		Items.IBUsers.CurrentRow = Rows[0].GetID();
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteIBUser(IBUserID, Cancel)
	
	Try
		Users.DeleteIBUser(IBUserID);
	Except
		CommonClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()), , , , Cancel);
	EndTry;	
	
EndProcedure

&AtClient
Procedure OpenUserByRef()
	
	CurrentData = Items.IBUsers.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ValueIsFilled(CurrentData.Ref) Then
		OpenForm(
			?(CurrentData.MappedToExternalUser,
				"Catalog.ExternalUsers.ObjectForm",
				"Catalog.Users.ObjectForm"),
			New Structure("Key", CurrentData.Ref));
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteCurrentIBUser(DeleteRow = False)
	
	ShowQueryBox(
		New NotifyDescription("DeleteCurrentIBUserCompletion", ThisObject, DeleteRow),
		NStr("ru = 'Удалить пользователя информационной базы?'; en = 'Do you want to delete the infobase user?'; pl = 'Usunąć użytkownika bazy informacyjnej?';es_ES = '¿Borrar el usuario de la infobase?';es_CO = '¿Borrar el usuario de la infobase?';tr = 'Veritabanı kullanıcısı silinsin mi?';it = 'Volete cancellare l''utente dell''infobase?';de = 'Infobase Benutzer löschen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure DeleteCurrentIBUserCompletion(Response, DeleteRow) Export
	
	If Response = DialogReturnCode.Yes Then
		Cancel = False;
		DeleteIBUser(
			Items.IBUsers.CurrentData.IBUserID, Cancel);
		
		If Not Cancel AND DeleteRow Then
			IBUsers.Delete(Items.IBUsers.CurrentData);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure MapIBUser(WithNew = False)
	
	If UsersTypes.Count() > 1 Then
		UsersTypes.ShowChooseItem(
			New NotifyDescription("MapIBUserForItemType", ThisObject, WithNew),
			NStr("ru = 'Выбор типа данных'; en = 'Select data type'; pl = 'Wybierz typ danych';es_ES = 'Seleccionar el tipo de datos';es_CO = 'Seleccionar el tipo de datos';tr = 'Veri türünü seçin';it = 'Selezione del tipo di dati';de = 'Wählen Sie den Datentyp aus'"),
			UsersTypes[0]);
	Else
		MapIBUserForItemType(UsersTypes[0], WithNew);
	EndIf;
	
EndProcedure

&AtClient
Procedure MapIBUserForItemType(ListItem, WithNew) Export
	
	If ListItem = Undefined Then
		Return;
	EndIf;
	
	CatalogName = ?(ListItem.Value = Type("CatalogRef.Users"), "Users", "ExternalUsers");
	
	If Not WithNew Then
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		FormParameters.Insert("NonExistingIBUsersIDs", NonExistingIBUsersIDs);
		
		OpenForm("Catalog." + CatalogName + ".ChoiceForm", FormParameters,,,,,
			New NotifyDescription("MapIBUserToItem", ThisObject, CatalogName));
	Else
		MapIBUserToItem("New", CatalogName);
	EndIf;
	
EndProcedure

&AtClient
Procedure MapIBUserToItem(Item, CatalogName) Export
	
	If Not ValueIsFilled(Item) AND Item <> "New" Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	
	If Item <> "New" Then
		FormParameters.Insert("Key", Item);
	EndIf;
	
	FormParameters.Insert("IBUserID",
		Items.IBUsers.CurrentData.IBUserID);
	
	OpenForm("Catalog." + CatalogName + ".ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure CancelMappingFollowUp(Response, Context) Export
	
	If Response = "CancelMapping" Then
		CancelMappingAtServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure CancelMappingAtServer()
	
	CurrentRow = IBUsers.FindByID(
		Items.IBUsers.CurrentRow);
	
	Object = CurrentRow.Ref.GetObject();
	Object.IBUserID = Undefined;
	Object.DataExchange.Load = True;
	Object.Write();
	
	FillIBUsers();
	
EndProcedure

#EndRegion
