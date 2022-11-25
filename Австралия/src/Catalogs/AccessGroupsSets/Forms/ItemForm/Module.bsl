#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ReadOnly = True;
	
	ChoiceList = Items.SetItemsType.ChoiceList;
	AddListItem(ChoiceList, "AccessGroups");
	AddListItem(ChoiceList, "UserGroups");
	AddListItem(ChoiceList, "Users");
	AddListItem(ChoiceList, "ExternalUsersGroups");
	AddListItem(ChoiceList, "ExternalUsers");
	
	SetAttributesPageByType(ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SetItemsTypeOnChange(Item)
	
	SetAttributesPageByType(ThisObject);
	Object.Folders.Clear();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
	ShowMessageBox(,
		NStr("ru = 'Набор групп доступа не следует изменять, так как он сопоставлен с разными ключами доступа.
		           |Чтобы исправить нестандартную проблему следует удалить набор групп доступа или
		           |связь с ним в регистрах и выполнить процедуру обновления доступа.'; 
		           |en = 'It is not recommend that you change the access group set as it is mapped with various access keys.
		           |To resolve a non-standard issue, delete the access group set or
		           |a link with it in registers and update access.'; 
		           |pl = 'Zestaw grup dostępu nie należy zmieniać, ponieważ on jest zestawiony z różnymi kluczami dostępu. 
		           |Aby poprawić nietypowy problem należy usunąć zestaw grup dostępu lub
		           |związek z nim w rejestrach i wykonać procedurę aktualizacji dostępu.';
		           |es_ES = 'No hay que cambiar el conjunto de grupos de acceso porque está vinculado con varias claves de acceso.
		           |Para corregir un problema no estándar hay que eliminar el conjunto de grupos de acceso o
		           |el vínculo con él en los registros y realizar el procedimiento de actualización de acceso.';
		           |es_CO = 'No hay que cambiar el conjunto de grupos de acceso porque está vinculado con varias claves de acceso.
		           |Para corregir un problema no estándar hay que eliminar el conjunto de grupos de acceso o
		           |el vínculo con él en los registros y realizar el procedimiento de actualización de acceso.';
		           |tr = 'Farklı nesnelerle eşleştirildiğinden erişim anahtarı değiştirilmemelidir.
		           |Standart olmayan bir sorunu gidermek için, erişim anahtarını veya 
		           |kayıtlarda onunla bağlantıyı kaldırmanız ve erişim güncelleme işlemini gerçekleştirmeniz gerekir.';
		           |it = 'È sconsigliata la modifica al set del gruppo di accesso poiché è mappato con diverse chiavi di accesso.
		           |Per risolvere un problema non standard, eliminare il set del gruppo di accesso o
		           |un collegarsi con esso all''accesso in registri e aggiornamenti.';
		           |de = 'Der Set von Zugriffsgruppen sollte nicht geändert werden, da er mit verschiedenen Zugriffsschlüsseln verknüpft ist.
		           |Um ein nicht standardmäßiges Problem zu beheben, entfernen Sie den Zugriffsgruppen-Set oder
		           |registrieren Sie die Kommunikation und führen Sie das Verfahren zur Aktualisierung des Zugriffs durch.'"));
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure AddListItem(ChoiceList, CatalogName)
	
	BlankID = New UUID("00000000-0000-0000-0000-000000000000");
	
	ChoiceList.Add(Catalogs[CatalogName].GetRef(BlankID),
		Metadata.Catalogs[CatalogName].Presentation());
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetAttributesPageByType(Form)
	
	If TypeOf(Form.Object.SetItemsType) = Type("CatalogRef.Users")
	 Or TypeOf(Form.Object.SetItemsType) = Type("CatalogRef.ExternalUsers") Then
		
		Form.Items.SetsAttributes.CurrentPage = Form.Items.SingleUserSetAttributes;
	Else
		Form.Items.SetsAttributes.CurrentPage = Form.Items.GroupsSetAttributes;
	EndIf;
	
EndProcedure

#EndRegion
