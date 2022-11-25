
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Not StandardSubsystemsServer.ApplicationVersionUpdatedDynamically() Then
		ListsWithRestriction = AccessManagementInternalCached.ListsWithRestriction();
	Else
		ListsWithRestriction = AccessManagementInternal.ActiveAccessRestrictionParameters(Undefined, Undefined);
	EndIf;
	
	Lists = New Array;
	Lists.Add("Catalog.AccessGroupsSets");
	For Each ListDetails In ListsWithRestriction Do
		FullName = ListDetails.Key;
		Lists.Add(FullName);
		If Not AccessManagementInternal.IsReferenceTableType(FullName) Then
			Continue;
		EndIf;
		BlankRef = PredefinedValue(FullName + ".EmptyRef");
		AccessUpdateObjectsTypes.Add(BlankRef, String(TypeOf(BlankRef)));
		AccessUpdateObjectsTypesTablesNames.Add(BlankRef, FullName);
	EndDo;
	AccessUpdateObjectsTypes.SortByPresentation();
	
	IDs = Common.MetadataObjectIDs(Lists);
	
	For Each IDDetails In IDs Do
		ListsForUpdate.Add(IDDetails.Value,
			String(IDDetails.Value));
	EndDo;
	
	ListsForUpdate.SortByPresentation();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AccessUpdateObjectStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentTypeItem = AccessUpdateObjectsTypes.FindByValue(
		SelectedAccessUpdateObjectType);
	
	If CurrentTypeItem = Undefined Then
		CurrentTypeItem = AccessUpdateObjectsTypes[0];
	EndIf;
	
	AccessUpdateObjectsTypes.ShowChooseItem(
		New NotifyDescription("BeginSelectUpdateObjectFollowUp", ThisObject),
		NStr("ru = 'Выбор типа данных'; en = 'Select data type'; pl = 'Wybierz typ danych';es_ES = 'Seleccionar el tipo de datos';es_CO = 'Seleccionar el tipo de datos';tr = 'Veri türünü seçin';it = 'Selezione del tipo di dati';de = 'Wählen Sie den Datentyp aus'"),
		CurrentTypeItem);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ShowAccessToObject(Command)
	
	If Not ValueIsFilled(AccessUpdateObject) Then
		ShowMessageBox(, NStr("ru = 'Выберите объект.'; en = 'Select an object.'; pl = 'Wybierz obiekt.';es_ES = 'Seleccionar el objeto.';es_CO = 'Seleccionar el objeto.';tr = 'Nesneyi seçin.';it = 'Seleziona un oggetto.';de = 'Wählen Sie ein Objekt aus.'"));
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateAccessToObject(Command)
	
	ShowMessageBox(, UpdateAccessToObjectAtServer());
	
EndProcedure

&AtClient
Procedure ScheduleUpdateOfAccessToAllSelectedListsItems(Command)
	
	ScheduleAccessUpdateToAllMarkedListsItemsAtServer();
	
	Notify("Write_UpdateDataAccessKeys", New Structure, Undefined);
	Notify("Write_UpdateUserAccessKeys", New Structure, Undefined);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function UpdateAccessToObjectAtServer()
	
	If Not ValueIsFilled(AccessUpdateObject) Then
		Return NStr("ru = 'Выберите объект.'; en = 'Select an object.'; pl = 'Wybierz obiekt.';es_ES = 'Seleccionar el objeto.';es_CO = 'Seleccionar el objeto.';tr = 'Nesneyi seçin.';it = 'Seleziona un oggetto.';de = 'Wählen Sie ein Objekt aus.'");
	EndIf;
	
	AccessManagementInternal.ClearAccessGroupsValuesCacheToCalculateRights();
	
	FullName = AccessUpdateObject.Metadata().FullName();
	TransactionID = New UUID;
	
	Text = "";
	
	UpdateAccessToObjectForUsersKind(AccessUpdateObject,
		FullName, TransactionID, False, Text);
	
	UpdateAccessToObjectForUsersKind(AccessUpdateObject,
		FullName, TransactionID, True, Text);
	
	Return Text;
	
EndFunction

&AtServer
Procedure UpdateAccessToObjectForUsersKind(ObjectRef, FullName, TransactionID, ForExternalUsers, Text)
	
	RestrictionParameters = AccessManagementInternal.RestrictionParameters(FullName,
		TransactionID, ForExternalUsers);
	
	Text = Text + ?(Text = "", "", Chars.LF + Chars.LF);
	If ForExternalUsers Then
		If RestrictionParameters.AccessDenied Then
			Text = Text + NStr("ru = 'Для внешних пользователей (доступ запрещен):'; en = 'For external users (access denied):'; pl = 'Dla użytkowników zewnętrznych (odmowa dostępu):';es_ES = 'Para usuarios externos (acceso prohibido):';es_CO = 'Para usuarios externos (acceso prohibido):';tr = 'Harici kullanıcılar için (erişim yasaklandı):';it = 'Per li utenti esterni (accesso vietato):';de = 'Für externe Benutzer (Zugriff verweigert):'");
			
		ElsIf RestrictionParameters.RestrictionDisabled Then
			Text = Text + NStr("ru = 'Для внешних пользователей (ограничение отключено):'; en = 'For external users (restriction disabled):'; pl = 'Dla użytkowników zewnętrznych (ograniczenie wyłączone):';es_ES = 'Para usuarios externos (restricción desactivada):';es_CO = 'Para usuarios externos (restricción desactivada):';tr = 'Harici kullanıcılar için (kısıtlama devre dışı bırakıldı):';it = 'Per utenti esterni (restrizione disabilitata):';de = 'Für externe Benutzer (Einschränkung deaktiviert):'");
		Else
			Text = Text + NStr("ru = 'Для внешних пользователей:'; en = 'For external users:'; pl = 'Dla użytkowników zewnętrznych:';es_ES = 'Para usuarios externos:';es_CO = 'Para usuarios externos:';tr = 'Harici kullanıcılar için:';it = 'Per utenti esterni';de = 'Für externe Benutzer:'");
		EndIf;
	Else
		If RestrictionParameters.AccessDenied Then
			Text = Text + NStr("ru = 'Для пользователей (доступ запрещен):'; en = 'For users (access denied):'; pl = 'Dla użytkowników (odmowa dostępu):';es_ES = 'Para usuarios (acceso prohibido):';es_CO = 'Para usuarios (acceso prohibido):';tr = 'Kullanıcılar için (erişim yasaklandı):';it = 'Per gli utenti (accesso vietato):';de = 'Für Benutzer (Zugriff verweigert):'");
			
		ElsIf RestrictionParameters.RestrictionDisabled Then
			Text = Text + NStr("ru = 'Для пользователей (ограничение отключено):'; en = 'For users (restriction disabled):'; pl = 'Dla użytkowników (ograniczenie wyłączone):';es_ES = 'Para usuarios (restricción desactivada):';es_CO = 'Para usuarios (restricción desactivada):';tr = 'Kullanıcılar için (kısıtlama devre dışı bırakıldı):';it = 'Per gli utenti (restrizione disabilitata):';de = 'Für Benutzer (Einschränkung deaktiviert):'");
		Else
			Text = Text + NStr("ru = 'Для пользователей:'; en = 'For users:'; pl = 'Dla użytkowników:';es_ES = 'Para usuarios:';es_CO = 'Para usuarios:';tr = 'Kullanıcılar için:';it = 'Per utenti';de = 'Für Benutzer:'");
		EndIf;
	EndIf;
	
	SourceAccessKeyObsolete = AccessManagementInternal.SourceAccessKeyObsolete(
		ObjectRef, RestrictionParameters);
	
	HasRightsChanges = False;
	
	AccessManagementInternal.UpdateAccessKeysOfDataItemsOnWrite(ObjectRef,
		RestrictionParameters, TransactionID, True, HasRightsChanges);
	
	If RestrictionParameters.RestrictionDisabled
	 Or RestrictionParameters.AccessDenied
	 Or RestrictionParameters.UsesRestrictionByOwner Then
		
		If Not RestrictionParameters.Property("DataItemForKeyClearingQueryText") Then
			If SourceAccessKeyObsolete Then
				Text = Text + Chars.LF + NStr("ru = '1. У объекта установлен всегда разрешенный ключ доступа.'; en = '1. The object access key is always allowed.'; pl = '1. Obiekt posiada ustawiony zawsze dozwolony klucz dostępu.';es_ES = '1. Para el objeto ha sido indicada siempre una clave de acceso permitida.';es_CO = '1. Para el objeto ha sido indicada siempre una clave de acceso permitida.';tr = '1. Nesnenin her zaman izin verilen bir erişim anahtarı vardır.';it = '1. La chiave di accesso all''oggetto è sempre consentita.';de = '1. Das Objekt hat immer einen gültigen Zugriffsschlüssel installiert.'");
			Else
				Text = Text + Chars.LF + NStr("ru = '1. Обновление не требуется. У объекта ключ доступа уже всегда разрешенный.'; en = '1. Update is not required. The object access key is always allowed.'; pl = '1. Aktualizacja nie jest wymagana. Obiekt już posiada ustawiony zawsze dozwolony klucz dostępu.';es_ES = '1. No se requiere la actualización. La clave del objeto está siempre permitida.';es_CO = '1. No se requiere la actualización. La clave del objeto está siempre permitida.';tr = '1. Güncelleme gerekmez. Nesnenin erişim anahtarına zaten izin verildi.';it = '1. Aggiornamento non richiesto. La chiave di accesso all''oggetto è sempre consentita.';de = '1. Eine Aktualisierung ist nicht erforderlich. Das Objekt hat einen Zugriffsschlüssel, der immer erlaubt ist.'");
			EndIf;
		Else
			If SourceAccessKeyObsolete Then
				Text = Text + Chars.LF + NStr("ru = '1. У объекта очищен ключ доступа.'; en = '1. The object access key is cleared.'; pl = '1. Klucz dostępu obiektu jest usunięty.';es_ES = '1. El objeto tiene una clave de acceso vaciada.';es_CO = '1. El objeto tiene una clave de acceso vaciada.';tr = '1. Nesnenin erişim anahtarı temizlendi.';it = '1. La chiave di accesso all''oggetto è cancellata.';de = '1. Das Objekt hat einen gelöschten Zugriffsschlüssel.'");
			Else
				Text = Text + Chars.LF + NStr("ru = '1. Обновление не требуется. У объекта ключ доступа уже пустой.'; en = '1. Update is not required. The object access key is already empty.'; pl = '1. Aktualizacja nie jest wymagana. Klucz dostępu obiektu jest już pusty.';es_ES = '1. La actualización no se requiere. El objeto tiene una clave de acceso vaciada ya.';es_CO = '1. La actualización no se requiere. El objeto tiene una clave de acceso vaciada ya.';tr = '1. Güncelleme gerekmez. Nesnenin erişim anahtarı zaten boş.';it = '1. Aggiornamento non richiesto. La chiave di accesso all''oggetto è già vuota.';de = '1. Eine Aktualisierung ist nicht erforderlich. Das Objekt hat einen leeren Zugriffsschlüssel.'");
			EndIf;
		EndIf;
	Else
		If SourceAccessKeyObsolete Then
			Text = Text + Chars.LF + NStr("ru = '1. У объекта обновлен ключ доступа.'; en = '1. The object access key is updated.'; pl = '1. Obiekt ma zaktualizowany klucz dostępu.';es_ES = '1. El objeto tiene una clave de acceso actualizada.';es_CO = '1. El objeto tiene una clave de acceso actualizada.';tr = '1. Nesnenin erişim anahtarı güncellendi.';it = '1. Chiave di accesso all''oggetto aggiornata.';de = '1. Das Objekt hat einen aktualisierten Zugriffsschlüssel.'");
		Else
			Text = Text + Chars.LF + NStr("ru = '1. Обновление не требуется. У объекта ключ доступа не устарел.'; en = '1. Update is not required. The object access key is not obsolete.'; pl = '1. Aktualizacja nie jest wymagana. Klucz dostępu do obiektu nie jest nieaktualny.';es_ES = '1. No se requiere actualización. La clave de acceso del objeto no se ha caducado.';es_CO = '1. No se requiere actualización. La clave de acceso del objeto no se ha caducado.';tr = '1. Güncelleme gerekmez. Nesnenin erişim anahtarı eskimedi.';it = '1. Aggiornamento non richiesto. La chiave di accesso all''oggetto non è obsoleta.';de = '1. Eine Aktualisierung ist nicht erforderlich. Der Zugriffsschlüssel des Objekts ist nicht veraltet.'");
		EndIf;
	EndIf;
	
	If RestrictionParameters.RestrictionDisabled
	 Or RestrictionParameters.AccessDenied
	 Or RestrictionParameters.UsesRestrictionByOwner Then
		
		If Not RestrictionParameters.Property("DataItemForKeyClearingQueryText") Then
			If HasRightsChanges Then
				Text = Text + Chars.LF
					+ NStr("ru = '2. У всегда разрешенного ключа доступа обновлен состав
					             |   групп доступа или пользователей или внешних пользователей.'; 
					             |en = '2. 
					             |Access groups, users, or external users of the access key, which is always allowed, have been updated.'; 
					             |pl = '2. Zawsze dozwolony klucz dostępu zaktualizował skład
					             | grup dostępu lub użytkowników lub użytkowników zewnętrznych.';
					             |es_ES = '2. El contenido de la clave de acceso siempre permitida ha sido actualizado
					             |   el grupo de acceso o de usuarios o de usuarios externos.';
					             |es_CO = '2. El contenido de la clave de acceso siempre permitida ha sido actualizado
					             |   el grupo de acceso o de usuarios o de usuarios externos.';
					             |tr = '2. Her zaman izin verilen erişim anahtarının, erişim gruplarının veya kullanıcıların veya harici kullanıcıların 
					             |kapsamı güncel.';
					             |it = '2. 
					             |Sono stati aggiornati i gruppi di accesso, gli utenti o gli utenti esterni della chiave di accesso sempre consentita.';
					             |de = '2. Der immer zulässige Zugriffsschlüssel hat die Zusammensetzung
					             |der Zugriffsgruppen oder Benutzer oder externen Benutzer aktualisiert.'");
			Else
				Text = Text + Chars.LF
					+ NStr("ru = '2. Обновление не требуется. У всегда разрешенного ключа доступа
					             |   состав групп доступа, пользователей и внешних пользователей не устарел.'; 
					             |en = '2. Update is not required. Access groups, users, or external users of the access key,
					             | which is always allowed, are not obsolete.'; 
					             |pl = '2. Aktualizacja nie jest wymagana. Zawsze dozwolony klucz dostępu
					             | listy grup dostępu, użytkowników i użytkowników zewnętrznych jest aktualny.';
					             |es_ES = '2. La actualización no se requiere. Para la clave siempre permitida
					             |   el contenido de grupos de acceso, de usuarios y usuarios externos no se ha caducado.';
					             |es_CO = '2. La actualización no se requiere. Para la clave siempre permitida
					             |   el contenido de grupos de acceso, de usuarios y usuarios externos no se ha caducado.';
					             |tr = '2. Güncelleme gerekmez. Her zaman izin 
					             |verilen erişim anahtarın erişim gruplarının, kullanıcıların ve harici kullanıcıların kapsamı eskimedi.';
					             |it = '2. Aggiornamento non richiesto. I gruppi di accesso, gli utenti o gli utenti esterni della chiave di accesso
					             | sempre consentita non sono obsoleti.';
					             |de = '2. Eine Aktualisierung ist nicht erforderlich. Mit dem immer zulässigen Zugriffsschlüssel
					             |ist die Zusammensetzung der Zugriffsgruppen, Benutzer und externen Benutzer nicht veraltet.'");
			EndIf;
		Else
			Text = Text + Chars.LF + NStr("ru = '2. Обновление не требуется. Пустой ключ доступа всегда запрещен.'; en = '2. Update is not required. Empty access key is always prohibited.'; pl = '2. Aktualizacja nie jest wymagana. Pusty klucz dostępu jest zawsze odrzucany.';es_ES = '2. No se requiere la actualización. La clave de acceso vacía está siempre prohibida.';es_CO = '2. No se requiere la actualización. La clave de acceso vacía está siempre prohibida.';tr = '2. Güncelleme gerekli değildir. Boş erişim anahtarı her zaman yasaktır.';it = '2. Aggiornamento non richiesto. La chiave di accesso vuota è sempre vietata.';de = '2. Eine Aktualisierung ist nicht erforderlich. Ein leerer Zugangsschlüssel ist immer verboten.'");
		EndIf;
		
	ElsIf HasRightsChanges Then
		If RestrictionParameters.HasUsersRestriction Then
			If ForExternalUsers Then
				Text = Text + Chars.LF + NStr("ru = '2. У ключа доступа обновлен состав внешних пользователей.'; en = '2. External users of the access key have been updated.'; pl = '2. Klucz dostępu zawiera zaktualizowaną listę użytkowników zewnętrznych.';es_ES = '2. El contenido de usuarios externos de la clave de acceso se ha actualizado.';es_CO = '2. El contenido de usuarios externos de la clave de acceso se ha actualizado.';tr = '2. Erişim anahtarının, harici kullanıcıların kapsamı güncellendi.';it = '2. Gli utenti esterni della chiave di accesso sono stati aggiornati.';de = '2. Der Zugriffsschlüssel verfügt über eine aktualisierte Zusammensetzung externer Benutzer.'");
			Else
				Text = Text + Chars.LF + NStr("ru = '2. У ключа доступа обновлен состав пользователей.'; en = '2. Users of the access key have been updated.'; pl = '2. Klucz dostępu zaktualizował listę użytkowników.';es_ES = '2. El contenido de usuarios de la clave de acceso se ha actualizado.';es_CO = '2. El contenido de usuarios de la clave de acceso se ha actualizado.';tr = '2. Erişim anahtarının, kullanıcıların kapsamı güncellendi.';it = '2. Gli utenti della chiave di accesso sono stati aggiornati.';de = '2. Der Zugriffsschlüssel verfügt über eine aktualisierte Zusammensetzung von Benutzern.'");
			EndIf;
		Else
			Text = Text + Chars.LF + NStr("ru = '2. У ключа доступа обновлен состав групп доступа.'; en = '2. Access groups of the access key have been updated.'; pl = '2. Klucz dostępu zaktualizował skład grup dostępu.';es_ES = '2. El contenido de grupos de acceso de la clave de acceso se ha actualizado.';es_CO = '2. El contenido de grupos de acceso de la clave de acceso se ha actualizado.';tr = '2. Erişim anahtarının, erişim grupların kapsamı güncellendi.';it = '2. I gruppi di accesso alla chiave di accesso sono stati aggiornati.';de = '2. Der Zugriffsschlüssel verfügt über eine aktualisierte Zusammensetzung von Zugriffsgruppen.'");
		EndIf;
	Else
		If RestrictionParameters.HasUsersRestriction Then
			If ForExternalUsers Then
				Text = Text + Chars.LF + NStr("ru = '2. Обновление не требуется. У ключа доступа состав внешних пользователей не устарел.'; en = '2. Update is not required. External users of the access key are not obsolete.'; pl = '2. Aktualizacja nie jest wymagana. W kluczu dostępu skład zewnętrznych użytkowników nie jest nieaktualny.';es_ES = '2. No se requiere la actualización. El contenido de los usuarios externos de la clave de acceso no se ha caducado.';es_CO = '2. No se requiere la actualización. El contenido de los usuarios externos de la clave de acceso no se ha caducado.';tr = '2. Güncelleme gerekmez. Erişim anahtarı dış kullanıcıların kapsamı eskimedi.';it = '2. Aggiornamento non richiesto. Gli utenti esterni della chiave di accesso non sono obsoleti.';de = '2. Eine Aktualisierung ist nicht erforderlich. Bei dem Zugriffsschlüssel ist die Zusammensetzung externer Benutzer nicht veraltet.'");
			Else
				Text = Text + Chars.LF + NStr("ru = '2. Обновление не требуется. У ключа доступа состав пользователей не устарел.'; en = '2. Update is not required. Users of the access key are not obsolete.'; pl = '2. Aktualizacja nie jest wymagana. W kluczu dostępu skład użytkowników nie jest nieaktualny.';es_ES = '2. No se requiere la actualización. El contenido de los usuarios de la clave de acceso no se ha caducado.';es_CO = '2. No se requiere la actualización. El contenido de los usuarios de la clave de acceso no se ha caducado.';tr = '2. Güncelleme gerekmez. Erişim anahtarın kullanıcı kapsamı eskimedi.';it = '2. Aggiornamento non richiesto. Gli utenti della chiave di accesso non sono obsoleti.';de = '2. Eine Aktualisierung ist nicht erforderlich. Bei dem Zugriffsschlüssel ist die Zusammensetzung der Benutzer nicht veraltet.'");
			EndIf;
		Else
			Text = Text + Chars.LF + NStr("ru = '2. Обновление не требуется. У ключа доступа состав групп доступа не устарел.'; en = '2. Update is not required. Access groups of the access key are not obsolete.'; pl = '2. Aktualizacja nie jest wymagana. W kluczu dostępu skład grup dostępu nie jest nieaktualny.';es_ES = '2. No se requiere la actualización. El contenido de los grupos de acceso de la clave de acceso no se ha caducado.';es_CO = '2. No se requiere la actualización. El contenido de los grupos de acceso de la clave de acceso no se ha caducado.';tr = '2. Güncelleme gerekmez. Erişim anahtarın erişim grupların kapsamı eskimedi.';it = '2. Aggiornamento non richiesto. I gruppi di accesso alla chiave di accesso non sono obsoleti.';de = '2. Eine Aktualisierung ist nicht erforderlich. Bei dem Zugriffsschlüssel ist die Zusammensetzung der Zugriffsgruppe nicht veraltet.'");
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure ScheduleAccessUpdateToAllMarkedListsItemsAtServer()
	
	Lists = New Array;
	For Each ListItem In ListsForUpdate Do
		If ListItem.Check Then
			Lists.Add(ListItem.Value);
		EndIf;
	EndDo;
	
	If Lists.Count() = ListsForUpdate.Count() Then
		Lists = Undefined;
	EndIf;
	
	AccessManagementInternal.ClearAccessGroupsValuesCacheToCalculateRights();
	AccessManagementInternal.ScheduleAccessUpdate(Lists);
	
	AccessManagementInternal.SetAccessUpdate(False);
	AccessManagementInternal.SetAccessUpdate(True);
	
EndProcedure

// AccessUpdateObjectStartChoice event handler continuation.
&AtClient
Procedure BeginSelectUpdateObjectFollowUp(SelectedItem, NotDefined) Export
	
	If SelectedItem = Undefined Then
		Return;
	EndIf;
	
	SelectedAccessUpdateObjectType = SelectedItem.Value;
	If TypeOf(AccessUpdateObject) <> TypeOf(SelectedAccessUpdateObjectType) Then
		AccessUpdateObject = SelectedAccessUpdateObjectType;
	EndIf;
	
	AccessValueStartChoiceCompletion();
	
EndProcedure

// Completes the AccessUpdateObjectStartChoice event handler.
&AtClient
Procedure AccessValueStartChoiceCompletion()
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow", AccessUpdateObject);
	
	ListItem = AccessUpdateObjectsTypesTablesNames.FindByValue(
		SelectedAccessUpdateObjectType);
	
	If ListItem = Undefined Then
		Return;
	EndIf;
	ChoiceFormName = ListItem.Presentation + ".ChoiceForm";
	
	OpenForm(ChoiceFormName, FormParameters, Items.AccessUpdateObject);
	
EndProcedure

#EndRegion
