
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "SelectionPick");
	Else
		Items.List.ChoiceMode = False;
	EndIf;
	
	PersonalAccessGroupsParent = Catalogs.AccessGroups.PersonalAccessGroupsParent(True);
	
	SimplifiedAccessRightsSetupInterface = AccessManagementInternal.SimplifiedAccessRightsSetupInterface();
	
	If SimplifiedAccessRightsSetupInterface Then
		CommonClientServer.SetFormItemProperty(Items,
			"FormCreate", "Visible", False);
		
		CommonClientServer.SetFormItemProperty(Items,
			"ListContextMenuCreate", "Visible", False);
		
		CommonClientServer.SetFormItemProperty(Items,
			"FormCopy", "Visible", False);
		
		CommonClientServer.SetFormItemProperty(Items,
			"ListContextMenuCopy", "Visible", False);
	EndIf;
	
	List.Parameters.SetParameterValue("Profile", Parameters.Profile);
	If ValueIsFilled(Parameters.Profile) Then
		Items.Profile.Visible = False;
		Items.List.Representation = TableRepresentation.List;
		AutoTitle = False;
		
		Title = NStr("ru = 'Группы доступа'; en = 'Access groups'; pl = 'Grupy dostępu';es_ES = 'Grupos de acceso';es_CO = 'Grupos de acceso';tr = 'Erişim grupları';it = 'Gruppi di accesso';de = 'Zugriffsgruppen'");
		
		CommonClientServer.SetFormItemProperty(Items,
			"FormCreateFolder", "Visible", False);
		
		CommonClientServer.SetFormItemProperty(Items,
			"ListContextMenuCreateGroup", "Visible", False);
	EndIf;
	
	If NOT AccessRight("Read", Metadata.Catalogs.AccessGroupProfiles) Then
		Items.Profile.Visible = False;
	EndIf;
	
	InaccessibleGroupsList = New ValueList;
	
	If NOT Users.IsFullUser() Then
		// Hiding the Administrators access group.
		CommonClientServer.SetDynamicListFilterItem(
			List, "Ref", Catalogs.AccessGroups.Administrators,
			DataCompositionComparisonType.NotEqual, , True);
	EndIf;
	
	ChoiceMode = Parameters.ChoiceMode;
	
	If Parameters.ChoiceMode Then
		
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		Items.List.ChoiceFoldersAndItems = Parameters.ChoiceFoldersAndItems;
		
		AutoTitle = False;
		If Parameters.CloseOnChoice = False Then
			// Pick mode.
			Items.List.MultipleChoice = True;
			Items.List.SelectionMode = TableSelectionMode.MultiRow;
			
			Title = NStr("ru = 'Подбор групп доступа'; en = 'Pick access groups'; pl = 'Wybierz grupy dostępu';es_ES = 'Elegir los grupos de acceso';es_CO = 'Elegir los grupos de acceso';tr = 'Erişim gruplarını seçin';it = 'Seleziona gruppi di accesso';de = 'Wählen Sie Zugriffsgruppen aus'");
		Else
			Title = NStr("ru = 'Выбор группы доступа'; en = 'Select access group'; pl = 'Wybierz grupę dostępu';es_ES = 'Seleccionar el grupo de acceso';es_CO = 'Seleccionar el grupo de acceso';tr = 'Erişim grubu seç';it = 'Seleziona gruppo di accesso';de = 'Wählen Sie Zugriffsgruppe aus'");
		EndIf;
	EndIf;
	
	If Common.IsStandaloneWorkplace() Then
		ReadOnly = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListOnChange(Item)
	
	ListOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	If Not StandardSubsystemsClient.IsDynamicListItem(Items.List) Then
		Return;
	EndIf;
	
	TransferAvailable = NOT ValueIsFilled(Items.List.CurrentData.User)
	                  AND Items.List.CurrentData.Ref <> PersonalAccessGroupsParent;
	
	CommonClientServer.SetFormItemProperty(Items,
		"FormMoveItem", "Enabled", TransferAvailable);
	
	CommonClientServer.SetFormItemProperty(Items,
		"ListContextMenuMoveItem", "Enabled", TransferAvailable);
	
	CommonClientServer.SetFormItemProperty(Items,
		"ListMoveItem", "Enabled", TransferAvailable);
	
EndProcedure

&AtClient
Procedure ListValueChoice(Item, Value, StandardProcessing)
	
	If Value = PersonalAccessGroupsParent Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("ru = 'Эта группа только для персональных групп доступа.'; en = 'This group is only for personal access groups.'; pl = 'Ten folder może zawierać tylko osobiste grupy dostępu.';es_ES = 'Esta carpeta puede contener solo los grupos de acceso personal.';es_CO = 'Esta carpeta puede contener solo los grupos de acceso personal.';tr = 'Bu grup sadece kişisel erişim grupları içindir.';it = 'Questo gruppo è riservato ai gruppi di accesso personale.';de = 'Dieser Ordner kann nur persönliche Zugriffsgruppen enthalten.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	If Parent = PersonalAccessGroupsParent Then
		
		Cancel = True;
		
		If IsFolder Then
			ShowMessageBox(, NStr("ru = 'В этой группе не используются подгруппы.'; en = 'Subgroups are not used in this group.'; pl = 'Ten folder nie może zawierać podfolderów.';es_ES = 'Esta carpeta no puede contener subcarpetas.';es_CO = 'Esta carpeta no puede contener subcarpetas.';tr = 'Bu klasör alt klasörler içeremez.';it = 'Non sono utilizzati sottogruppi in questo gruppo.';de = 'Dieser Ordner darf keine Unterordner enthalten.'"));
			
		ElsIf SimplifiedAccessRightsSetupInterface Then
			ShowMessageBox(,
				NStr("ru = 'Персональные группы доступа
				           |создаются только в форме ""Права доступа"".'; 
				           |en = 'Personal access groups
				           |can be created only in the ""Access rights"" form.'; 
				           |pl = 'Prywatne grupy dostępu
				           |są tworzone tylko w formularzu ""Prawa dostępu"".';
				           |es_ES = 'Los grupos de acceso personales
				           |se crean solo en el formulario ""Derechos de acceso"".';
				           |es_CO = 'Los grupos de acceso personales
				           |se crean solo en el formulario ""Derechos de acceso"".';
				           |tr = 'Kişisel erişim grubu yalnızca 
				           |""Erişim hakları"" formunda oluşturulabilir.';
				           |it = 'I gruppi di accesso personali
				           |vengono creati solamente in forma ""Diritti d''accesso"".';
				           |de = 'Persönliche Zugangsgruppen
				           |werden nur in Form von ""Zugriffsrechte"" erstellt.'"));
		Else
			ShowMessageBox(, NStr("ru = 'Персональные группы доступа не используются.'; en = 'Personal access groups are not used.'; pl = 'Prywatne grupy dostępu nie są dostępne.';es_ES = 'Grupos de acceso personal no están disponibles.';es_CO = 'Grupos de acceso personal no están disponibles.';tr = 'Kişisel erişim grupları mevcut değildir.';it = 'I gruppi di accesso personalizzati non sono utilizzati.';de = 'Persönliche Zugriffsgruppen sind nicht verfügbar.'"));
		EndIf;
		
	ElsIf NOT IsFolder
	        AND SimplifiedAccessRightsSetupInterface Then
		
		Cancel = True;
		
		ShowMessageBox(,
			NStr("ru = 'Используются только персональные группы доступа,
			           |которые создаются только в форме ""Права доступа"".'; 
			           |en = 'Only personal access groups
			           |created in the ""Access rights"" form are used.'; 
			           |pl = 'Są używane wyłącznie prywatne grupy dostępu,
			           |które są tworzone tylko w formularzu ""Prawa dostępu"".';
			           |es_ES = 'Se usan solo grupos de acceso personales
			           |que se crean solo en el formulario ""Derechos de acceso"".';
			           |es_CO = 'Se usan solo grupos de acceso personales
			           |que se crean solo en el formulario ""Derechos de acceso"".';
			           |tr = 'Yalnızca ""Erişim hakları"" formunda oluşturulan kişisel erişim grupları 
			           |kullanılabilir.';
			           |it = 'Sono utilizzati sono gruppi di accesso personale
			           |creati nel modulo ""Diritti di accesso"".';
			           |de = 'Es werden nur persönliche Zugriffsgruppen verwendet,
			           |die nur in Form von ""Zugriffsrechte"" erstellt werden.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeChangeRow(Item, Cancel)
	
	CurrentData = Item.CurrentData;
	
	If CurrentData = Undefined
	 Or CurrentData.IsFolder Then
		Return;
	EndIf;
	
	Cancel = True;
	
	FormParameters = New Structure("Key", CurrentData.Ref);
	OpenForm("Catalog.AccessGroups.ObjectForm", FormParameters, Item);
	
EndProcedure

&AtServerNoContext
Procedure ListOnReceiveDataAtServer(ItemName, Settings, Rows)
	
	For Each Row In Rows Do
		If TypeOf(Row.Key) <> Type("CatalogRef.AccessGroups") Then
			Continue;
		EndIf;
		Data = Row.Value.Data;
		
		If Data.IsFolder
		 Or Not ValueIsFilled(Data.User) Then
			Continue;
		EndIf;
		
		Data.Description =
			AccessManagementInternalClientServer.PresentationAccessGroups(Data);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ListDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	If Row = PersonalAccessGroupsParent Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("ru = 'Эта папка только для персональных групп доступа.'; en = 'This folder is for personal access groups only.'; pl = 'Ten folder może zawierać tylko prywatne grupy dostępu.';es_ES = 'Esta carpeta puede contener solo los grupos de acceso personal.';es_CO = 'Esta carpeta puede contener solo los grupos de acceso personal.';tr = 'Bu klasör sadece kişisel erişim grupları içindir.';it = 'Questa cartella è solo per gruppi di accesso personali.';de = 'Dieser Ordner kann nur persönliche Zugriffsgruppen enthalten.'"));
		
	ElsIf DragParameters.Value = PersonalAccessGroupsParent Then
		StandardProcessing = False;
		ShowMessageBox(, NStr("ru = 'Папка персональных групп доступа не переносится.'; en = 'Personal access groups folder cannot be moved.'; pl = 'Nie można przenieść folderu prywatnych grup dostępu.';es_ES = 'No se puede mover la carpeta de los grupos de acceso personal.';es_CO = 'No se puede mover la carpeta de los grupos de acceso personal.';tr = 'Kişisel erişim grupları klasörü taşınamaz.';it = 'La cartella dei gruppi di accesso personale non può essere spostata.';de = 'Der Ordner für persönliche Zugriffsgruppen kann nicht verschoben werden.'"));
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure ListOnChangeAtServer()
	
	AccessManagementInternal.AfterChangeRightsSettingsInForm();
	
EndProcedure

#EndRegion
