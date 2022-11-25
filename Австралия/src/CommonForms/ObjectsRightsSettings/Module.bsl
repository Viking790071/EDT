
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ObjectRef = Parameters.ObjectRef;
	If Not ValueIsFilled(ObjectRef) Then
		Raise NStr("ru = 'Не указан владелец настроек прав.'; en = 'Rights settings owner is not specified.'; pl = 'Nie wskazano właściciela ustawień uprawnień.';es_ES = 'No se ha indicado propietario de ajustes de derechos.';es_CO = 'No se ha indicado propietario de ajustes de derechos.';tr = 'Hak ayarların sahibi belirtilmedi.';it = 'Proprietario impostazioni diritti non specificato.';de = 'Der Eigentümer der Rechteeinstellungen ist nicht angegeben.'");
	EndIf;
	
	AvailableRights = AccessManagementInternalCached.RightsForObjectsRightsSettingsAvailable();
	ObjectRefType = TypeOf(ObjectRef);
	
	If AvailableRights.ByRefsTypes.Get(ObjectRefType) = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Права доступа для каждого объекта не настраиваются
			           |для объектов типа ""%1"".'; 
			           |en = 'Access rights for each object cannot be set
			           |for objects of the ""%1"" type.'; 
			           |pl = 'Prawa dostępu dla każdego obiektu nie są ustawiane
			           |dla obiektów typu ""%1"".';
			           |es_ES = 'Los ajustes de derechos para cada objeto no se ajustan
			           |para los objetos del tipo ""%1"".';
			           |es_CO = 'Los ajustes de derechos para cada objeto no se ajustan
			           |para los objetos del tipo ""%1"".';
			           |tr = 'Her nesnenin erişim hakları %1"
" tipi nesneler için yapılandırılmamaktadır.';
			           |it = 'I diritti di accesso per ciascun oggetto non possono essere impostati
			           |per gli oggetti del tipo ""%1"".';
			           |de = 'Die Zugriffsrechte für jedes Objekt sind
			           |für Objekte vom Typ ""%1"" nicht konfigurierbar.'"),
			String(ObjectRefType));
	EndIf;
	
	If Not AccessRight("View", Metadata.FindByType(ObjectRefType)) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Нет права Просмотр на объекты типа ""%1"".'; en = 'There is no View right for objects of the ""%1"" type.'; pl = 'Brak prawa Przeglądanie do obiektów typu ""%1"".';es_ES = 'No hay derecho Ver de los objetos del tipo ""%1"".';es_CO = 'No hay derecho Ver de los objetos del tipo ""%1"".';tr = '""%1"" tür nesneler için Görüntüleme hakkı yok.';it = 'Non vi è il diritto Visualizzazione per gli oggetti del tipo ""%1"".';de = 'Es gibt keine Berechtigung, Objekte vom Typ ""%1"" zu sehen.'"), String(ObjectRefType));
	EndIf;
	
	// Checking the permissions to open a form
	ValidatePermissionToManageRights();
	
	UseExternalUsers =
		ExternalUsers.UseExternalUsers()
		AND AccessRight("View", Metadata.Catalogs.ExternalUsers);
	
	SetPrivilegedMode(True);
	
	UserTypesList.Add(Type("CatalogRef.Users"),
		Metadata.Catalogs.Users.Synonym);
	
	UserTypesList.Add(Type("CatalogRef.ExternalUsers"),
		Metadata.Catalogs.ExternalUsers.Synonym);
	
	ParentFilled =
		Parameters.ObjectRef.Metadata().Hierarchical
		AND ValueIsFilled(Common.ObjectAttributeValue(Parameters.ObjectRef, "Parent"));
	
	Items.InheritParentRights.Visible = ParentFilled;
	
	RightsSettings = InformationRegisters.ObjectsRightsSettings.Read(Parameters.ObjectRef);
	
	FillRights();
	
	If CommonClientServer.IsMobileClient() Then
		
		CommonClientServer.SetFormItemProperty(Items, "FormWriteAndClose", "Title", NStr("ru ='ОК'; en = 'OK'; pl = 'OK';es_ES = 'OK';es_CO = 'Ok';tr = 'Tamam';it = 'OK';de = 'Ok'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseNotification", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure InheritParentsRightsOnChange(Item)
	
	InheritParentsRightsOnChangeAtServer();
	
EndProcedure

&AtServer
Procedure InheritParentsRightsOnChangeAtServer()
	
	If InheritParentRights Then
		AddInheritedRights();
		FillUserPictureNumbers();
	Else
		// Clearing settings inherited from the hierarchical parents.
		Index = RightsGroups.Count()-1;
		While Index >= 0 Do
			If RightsGroups.Get(Index).ParentSetting Then
				RightsGroups.Delete(Index);
			EndIf;
			Index = Index - 1;
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

#Region RightsGroupFormTableItemsEventHandlers

&AtClient
Procedure RightsGroupsOnChange(Item)
	
	RightsGroups.Sort("ParentSetting Desc");
	
EndProcedure

&AtClient
Procedure RightsGroupsSelection(Item, RowSelected, Field, StandardProcessing)
	
	If Field.Name = "RightsGroupsUser" Then
		Return;
	EndIf;
	
	Cancel = False;
	CheckOpportunityToChangeRights(Cancel);
	
	If NOT Cancel Then
		CurrentRight  = Mid(Field.Name, StrLen("RightsGroups") + 1);
		CurrentData = Items.RightsGroups.CurrentData;
		
		If CurrentRight = "InheritanceIsAllowed" Then
			CurrentData[CurrentRight] = NOT CurrentData[CurrentRight];
			Modified = True;
			
		ElsIf AvailableRights.Property(CurrentRight) Then
			PreviousValue = CurrentData[CurrentRight];
			
			If CurrentData[CurrentRight] = True Then
				CurrentData[CurrentRight] = False;
				
			ElsIf CurrentData[CurrentRight] = False Then
				CurrentData[CurrentRight] = Undefined;
			Else
				CurrentData[CurrentRight] = True;
			EndIf;
			Modified = True;
			
			UpdateDependentRights(CurrentData, CurrentRight, PreviousValue);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure RightsGroupsOnActivateRow(Item)
	
	CurrentData = Items.RightsGroups.CurrentData;
	
	CommandsAvailability = ?(CurrentData = Undefined, False, NOT CurrentData.ParentSetting);
	Items.RightsGroupsContextMenuDelete.Enabled = CommandsAvailability;
	Items.FormDelete.Enabled                     = CommandsAvailability;
	Items.FormMoveUp.Enabled            = CommandsAvailability;
	Items.FormMoveDown.Enabled             = CommandsAvailability;
	
EndProcedure

&AtClient
Procedure RightsGroupsOnActivateField(Item)
	
	CommandsAvailability = AvailableRights.Property(Mid(Item.CurrentItem.Name, StrLen("RightsGroups") + 1));
	Items.RightsGroupsContextMenuDisableRight.Enabled       = CommandsAvailability;
	Items.RightsGroupsContextMenuGrantRight.Enabled = CommandsAvailability;
	Items.RightsGroupsContextMenuDenyRight.Enabled     = CommandsAvailability;
	
EndProcedure

&AtClient
Procedure RightsGroupsBeforeChange(Item, Cancel)
	
	CheckOpportunityToChangeRights(Cancel);
	
EndProcedure

&AtClient
Procedure RightsGroupsBeforeDelete(Item, Cancel)
	
	CheckOpportunityToChangeRights(Cancel, True);
	
EndProcedure

&AtClient
Procedure RightsGroupsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		
		// Setting initial values.
		Items.RightsGroups.CurrentData.SettingsOwner     = Parameters.ObjectRef;
		Items.RightsGroups.CurrentData.InheritanceIsAllowed = True;
		Items.RightsGroups.CurrentData.ParentSetting     = False;
		
		For each AddedAttribute In AddedAttributes Do
			Items.RightsGroups.CurrentData[AddedAttribute.Key] = AddedAttribute.Value;
		EndDo;
	EndIf;
	
	If Items.RightsGroups.CurrentData.User = Undefined Then
		Items.RightsGroups.CurrentData.User  = PredefinedValue("Catalog.Users.EmptyRef");
		Items.RightsGroups.CurrentData.PictureNumber = -1;
	EndIf;
	
EndProcedure

&AtClient
Procedure RightsGroupsUserOnChange(Item)
	
	If ValueIsFilled(Items.RightsGroups.CurrentData.User) Then
		FillUserPictureNumbers(Items.RightsGroups.CurrentRow);
	Else
		Items.RightsGroups.CurrentData.PictureNumber = -1;
	EndIf;
	
EndProcedure

&AtClient
Procedure RightsGroupsUserStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectUsers();
	
EndProcedure

&AtClient
Procedure RightsGroupsUserClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	Items.RightsGroups.CurrentData.User  = PredefinedValue("Catalog.Users.EmptyRef");
	Items.RightsGroups.CurrentData.PictureNumber = -1;
	
EndProcedure

&AtClient
Procedure RightsGroupsUserTextInputCompletion(Item, Text, ChoiceData, DataGetParameters)
	
	If ValueIsFilled(Text) Then 
		DataGetParameters = False;
		ChoiceData = GenerateUserSelectionData(Text);
	EndIf;
	
EndProcedure

&AtClient
Procedure RightsGroupsUserAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting)
	
	If ValueIsFilled(Text) Then
		Waiting = False;
		ChoiceData = GenerateUserSelectionData(Text);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	WriteBeginning(True);
	
EndProcedure

&AtClient
Procedure Write(Command)
	
	WriteBeginning();
	
EndProcedure

&AtClient
Procedure Reread(Command)
	
	If NOT Modified Then
		ReadRights();
	Else
		ShowQueryBox(
			New NotifyDescription("RereadEnd", ThisObject),
			NStr("ru = 'Данные изменены. Прочитать без сохранения?'; en = 'Data is changed. Read without saving?'; pl = 'Dane zostały zmienione. Odczytać bez zapisywania?';es_ES = 'Datos se han cambiado. ¿Leer sin guardar?';es_CO = 'Datos se han cambiado. ¿Leer sin guardar?';tr = 'Veriler değişti. Kaydetmeden okunsun mu?';it = 'I dati vengono modificati. Leggere senza salvare?';de = 'Daten werden geändert. Lesen ohne zu speichern?'"),
			QuestionDialogMode.YesNo,
			5,
			DialogReturnCode.No);
	EndIf;
	
EndProcedure

&AtClient
Procedure DisableRight(Command)
	
	SetCurrentRightValue(Undefined);
	
EndProcedure

&AtClient
Procedure DenyRight(Command)
	
	SetCurrentRightValue(False);
	
EndProcedure

&AtClient
Procedure GrantRight(Command)
	
	SetCurrentRightValue(True);
	
EndProcedure

&AtClient
Procedure SetCurrentRightValue(NewValue)
	
	Cancel = False;
	CheckOpportunityToChangeRights(Cancel);
	
	If Not Cancel Then
		CurrentRight  = Mid(Items.RightsGroups.CurrentItem.Name, StrLen("RightsGroups") + 1);
		CurrentData = Items.RightsGroups.CurrentData;
		
		If AvailableRights.Property(CurrentRight)
		   AND CurrentData <> Undefined Then
			
			PreviousValue = CurrentData[CurrentRight];
			CurrentData[CurrentRight] = NewValue;
			
			Modified = True;
			
			UpdateDependentRights(CurrentData, CurrentRight, PreviousValue);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RightsGroups.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RightsGroups.ParentSetting");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.Gray);

EndProcedure

&AtClient
Procedure WriteAndCloseNotification(Result, Context) Export
	
	WriteBeginning(True);
	
EndProcedure

&AtClient
Procedure WriteBeginning(Close = False)
	
	Cancel = False;
	FillCheckProcessing(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	ConfirmRightsManagementCancellation = Undefined;
	Try
		WriteRights();
	Except
		If ConfirmRightsManagementCancellation <> True Then
			Raise;
		EndIf;
	EndTry;
	
	If ConfirmRightsManagementCancellation = True Then
		Buttons = New ValueList;
		Buttons.Add("WriteAndClose", NStr("ru = 'Записать и закрыть'; en = 'Save and close'; pl = 'Zapisz i zamknij';es_ES = 'Guardar y cerrar';es_CO = 'Guardar y cerrar';tr = 'Sakla ve kapat';it = 'Salva e chiudi';de = 'Speichern und schließen'"));
		Buttons.Add("Cancel", NStr("ru = 'Отмена'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annulla';de = 'Abbrechen'"));
		ShowQueryBox(
			New NotifyDescription("SaveAfterConfirmation", ThisObject),
			NStr("ru = 'После записи настройка прав станет недоступной.'; en = 'Rights setting will be disabled after saving.'; pl = 'Po zapisaniu nie można przypisać praw dostępu.';es_ES = 'Después de la grabación, usted no puede asignar los derechos de acceso.';es_CO = 'Después de la grabación, usted no puede asignar los derechos de acceso.';tr = 'Yazdıktan sonra, erişim hakları atayamazsınız.';it = 'Le impostazioni dei permessi saranno disabilitate dopo il salvataggio.';de = 'Nach dem Schreiben können Sie keine Zugriffsrechte zuweisen.'"),
			Buttons,, "Cancel");
	Else
		If Close Then
			Close();
		Else
			ClearMessages();
		EndIf;
		WriteCompletion();
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveAfterConfirmation(Response, Context) Export
	
	If Response = "WriteAndClose" Then
		ConfirmRightsManagementCancellation = False;
		WriteRights();
		Close();
	EndIf;
	
	WriteCompletion();
	
EndProcedure

&AtClient
Procedure WriteCompletion()
	
	Notify("Write_ObjectRightsSettings", , Parameters.ObjectRef);
	
EndProcedure

&AtClient
Procedure RereadEnd(Response, Context) Export
	
	If Response = DialogReturnCode.Yes Then
		ReadRights();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

&AtClient
Procedure UpdateDependentRights(Val Data, Val Right, Val PreviousValue, Val RecursionDepth = 0)
	
	If Data[Right] = PreviousValue Then
		Return;
	EndIf;
	
	If RecursionDepth > 100 Then
		Return;
	Else
		RecursionDepth = RecursionDepth + 1;
	EndIf;
	
	DependentRights = Undefined;
	
	If Data[Right] = True Then
		
		// Permissions increased (from Undefined or False to True).
		// It is required to increase permissions for leading rights.
		DirectRightsDependencies.Property(Right, DependentRights);
		DependentRightValue = True;
		
	ElsIf Data[Right] = False Then
		
		// Prohibitions increased (from True or Undefined to False).
		// It is required to increase denying for dependent rights.
		ReverseRightsDependencies.Property(Right, DependentRights);
		DependentRightValue = False;
	Else
		If PreviousValue = False Then
			// Denying decreased (from False to Undefined).
			// It is required to decrease denying for leading rights.
			DirectRightsDependencies.Property(Right, DependentRights);
			DependentRightValue = Undefined;
		Else
			// Permissions decreased (from True to Undefined).
			// It is required to decrease permissions for dependent rights.
			ReverseRightsDependencies.Property(Right, DependentRights);
			DependentRightValue = Undefined;
		EndIf;
	EndIf;
	
	If DependentRights <> Undefined Then
		For each DependentRight In DependentRights Do
			If TypeOf(DependentRight) = Type("Array") Then
				SetDependentRight = True;
				For each OneOfDependentRights In DependentRight Do
					If Data[OneOfDependentRights] = DependentRightValue Then
						SetDependentRight = False;
						Break;
					EndIf;
				EndDo;
				If SetDependentRight Then
					If NOT (DependentRightValue = Undefined AND Data[DependentRight[0]] <> PreviousValue) Then
						CurrentPreviousValue = Data[DependentRight[0]];
						Data[DependentRight[0]] = DependentRightValue;
						UpdateDependentRights(Data, DependentRight[0], CurrentPreviousValue);
					EndIf;
				EndIf;
			Else
				If NOT (DependentRightValue = Undefined AND Data[DependentRight] <> PreviousValue) Then
					CurrentPreviousValue = Data[DependentRight];
					Data[DependentRight] = DependentRightValue;
					UpdateDependentRights(Data, DependentRight, CurrentPreviousValue);
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure AddAttribute(NewAttributes, Attribute, InitialValue)
	
	NewAttributes.Add(Attribute);
	AddedAttributes.Insert(Attribute.Name, InitialValue);
	
EndProcedure

&AtServer
Function AddItem(Name, Type, Parent)
	
	Item = Items.Add(Name, Type, Parent);
	Item.FixingInTable = FixingInTable.None;
	
	Return Item;
	
EndFunction

&AtServer
Procedure AddAttributesOrFormItems(NewAttributes = Undefined)
	
	Rights = AccessManagementInternalCached.RightsForObjectsRightsSettingsAvailable();
	PossibleRightsDetails = Rights.ByRefsTypes.Get(TypeOf(Parameters.ObjectRef));
	
	PseudoFlagTypesDetails = New TypeDescription("Boolean, Number",
		New NumberQualifiers(1, 0, AllowedSign.Nonnegative));
	
	// Adding available rights restricted by an owner (by an access value table).
	For each RightDetails In PossibleRightsDetails Do
		
		If NewAttributes <> Undefined Then
			
			AddAttribute(NewAttributes, New FormAttribute(RightDetails.Name, PseudoFlagTypesDetails,
				"RightsGroups", RightDetails.Title), RightDetails.InitialValue);
			
			AvailableRights.Insert(RightDetails.Name);
			
			// Adding direct and reverse rights dependencies.
			DirectRightsDependencies.Insert(RightDetails.Name, RightDetails.RequiredRights);
			For each DependentRight In RightDetails.RequiredRights Do
				If TypeOf(DependentRight) = Type("Array") Then
					DependentRights = DependentRight;
				Else
					DependentRights = New Array;
					DependentRights.Add(DependentRight);
				EndIf;
				For each DependentRight In DependentRights Do
					If ReverseRightsDependencies.Property(DependentRight) Then
						DependentRights = ReverseRightsDependencies[DependentRight];
					Else
						DependentRights = New Array;
						ReverseRightsDependencies.Insert(DependentRight, DependentRights);
					EndIf;
					If DependentRights.Find(RightDetails.Name) = Undefined Then
						DependentRights.Add(RightDetails.Name);
					EndIf;
				EndDo;
			EndDo;
		Else
			Item = AddItem("RightsGroups" + RightDetails.Name, Type("FormField"), Items.RightsGroups);
			Item.ReadOnly                = True;
			Item.Format                        = "ND=1; NZ=; BF=Нет; BT=Да";
			Item.HeaderHorizontalAlign = ItemHorizontalLocation.Center;
			Item.HorizontalAlign       = ItemHorizontalLocation.Center;
			Item.DataPath                   = "RightsGroups." + RightDetails.Name;
			
			Item.ToolTip = RightDetails.ToolTip;
			// Calculating the optimal item width.
			ItemWidth = 0;
			For RowNumber = 1 To StrLineCount(RightDetails.Title) Do
				ItemWidth = Max(ItemWidth, StrLen(StrGetLine(RightDetails.Title, RowNumber)));
			EndDo;
			If StrLineCount(RightDetails.Title) = 1 Then
				ItemWidth = ItemWidth + 1;
			EndIf;
			Item.Width = ItemWidth;
		EndIf;
		
		If Items.RightsGroups.HeaderHeight < StrLineCount(RightDetails.Title) Then
			Items.RightsGroups.HeaderHeight = StrLineCount(RightDetails.Title);
		EndIf;
	EndDo;
	
	If NewAttributes = Undefined AND Parameters.ObjectRef.Metadata().Hierarchical Then
		Item = AddItem("RightsGroupsInheritanceAllowed", Type("FormField"), Items.RightsGroups);
		Item.ReadOnly                = True;
		Item.Format                        = "ND=1; NZ=; BF=Нет; BT=Да";
		Item.HeaderHorizontalAlign = ItemHorizontalLocation.Center;
		Item.HorizontalAlign       = ItemHorizontalLocation.Center;
		Item.DataPath                   = "RightsGroups.InheritanceIsAllowed";
		
		Item.Title = NStr("ru = 'Для
		                               |подпапок'; 
		                               |en = 'For
		                               |subfolders'; 
		                               |pl = 'Do
		                               |podfolderów';
		                               |es_ES = 'Para
		                               |subcarpetas';
		                               |es_CO = 'Para
		                               |subcarpetas';
		                               |tr = '
		                               |Alt klasörler için';
		                               |it = 'Per
		                               |sottocartelle';
		                               |de = 'Für
		                               |Unterordner'");
		Item.ToolTip = NStr("ru = 'Права не только для текущей папки,
		                               |но и для ее нижестоящих папок'; 
		                               |en = 'Rights not only for the current folder
		                               |but also for its subfolders'; 
		                               |pl = 'Uprawnienia nie tylko dla bieżącego folderu,
		                               |ale także dla jego folderów podporządkowanych';
		                               |es_ES = 'Derechos no solo para la carpeta actual,
		                               |sino también para sus subcarpetas';
		                               |es_CO = 'Derechos no solo para la carpeta actual,
		                               |sino también para sus subcarpetas';
		                               |tr = 'Haklar sadece geçerli klasör için değil, 
		                               |aynı zamanda alt klasörler için de';
		                               |it = 'Permessi non solo per la cartella corrente
		                               |ma anche per le sue sottocartelle';
		                               |de = 'Berechtigungen nicht nur für den aktuellen Ordner,
		                               |sondern auch für die untergeordneten Ordner.'");
		
		Item = AddItem("RightsGroupsOwnerSettings", Type("FormField"), Items.RightsGroups);
		Item.ReadOnly = True;
		Item.DataPath    = "RightsGroups.SettingsOwner";
		Item.Title = NStr("ru = 'Наследуется от'; en = 'Inherited from'; pl = 'Odziedziczony po';es_ES = 'Heredado de';es_CO = 'Heredado de';tr = 'Devreden';it = 'Ereditato da';de = 'Geerbt von'");
		Item.ToolTip = NStr("ru = 'Папка, от которой наследуются настройка прав'; en = 'Folder, from which the rights setting is inherited'; pl = 'Folder, po którym dziedziczone są ustawienia praw dostępu';es_ES = 'Carpeta de la cual las configuraciones de los derechos de acceso se han heredado';es_CO = 'Carpeta de la cual las configuraciones de los derechos de acceso se han heredado';tr = 'Erişim hakları ayarlarının devralındığı klasör';it = 'Cartella dalla quale viene ereditata l''impostazione dei diritti';de = 'Ordner, von dem die Zugriffsrechte übernommen werden'");
		Item.Visible = ParentFilled;
		
		ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
		ConditionalAppearanceItem.Use = True;
		ConditionalAppearanceItem.Appearance.SetParameterValue("Text", "");
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(
			Type("DataCompositionFilterItem"));
		FilterItem.Use  = True;
		FilterItem.LeftValue  = New DataCompositionField("RightsGroups.ParentSetting");
		FilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = False;
		
		FormattedField = ConditionalAppearanceItem.Fields.Items.Add();
		FormattedField.Use = True;
		FormattedField.Field = New DataCompositionField("RightsGroupsOwnerSettings");
		
		If Items.RightsGroups.HeaderHeight = 1 Then
			Items.RightsGroups.HeaderHeight = 2;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillRights()
	
	DirectRightsDependencies   = New Structure;
	ReverseRightsDependencies = New Structure;
	AvailableRights          = New Structure;
	
	AddedAttributes = New Structure;
	NewAttributes = New Array;
	AddAttributesOrFormItems(NewAttributes);
	
	// Adding form attributes.
	ChangeAttributes(NewAttributes);
	
	// Adding form items
	AddAttributesOrFormItems();
	
	ReadRights();
	
EndProcedure

&AtServer
Procedure ReadRights()
	
	RightsGroups.Clear();
	
	SetPrivilegedMode(True);
	RightsSettings = InformationRegisters.ObjectsRightsSettings.Read(Parameters.ObjectRef);
	
	InheritParentRights = RightsSettings.Inherit;
	
	For each Setting In RightsSettings.Settings Do
		If InheritParentRights OR NOT Setting.ParentSetting Then
			FillPropertyValues(RightsGroups.Add(), Setting);
		EndIf;
	EndDo;
	FillUserPictureNumbers();
	
	Modified = False;
	
EndProcedure

&AtServer
Procedure AddInheritedRights()
	
	SetPrivilegedMode(True);
	RightsSettings = InformationRegisters.ObjectsRightsSettings.Read(Parameters.ObjectRef);
	
	Index = 0;
	For each Setting In RightsSettings.Settings Do
		If Setting.ParentSetting Then
			FillPropertyValues(RightsGroups.Insert(Index), Setting);
			Index = Index + 1;
		EndIf;
	EndDo;
	
	FillUserPictureNumbers();
	
EndProcedure

&AtClient
Procedure FillCheckProcessing(Cancel)
	
	ClearMessages();
	
	RowNumber = RightsGroups.Count()-1;
	
	While NOT Cancel AND RowNumber >= 0 Do
		CurrentRow = RightsGroups.Get(RowNumber);
		
		// Checking whether the rights check boxes are filled.
		NoFilledRight = True;
		FirstRightName = "";
		For each PossibleRight In AvailableRights Do
			If NOT ValueIsFilled(FirstRightName) Then
				FirstRightName = PossibleRight.Key;
			EndIf;
			If TypeOf(CurrentRow[PossibleRight.Key]) = Type("Boolean") Then
				NoFilledRight = False;
				Break;
			EndIf;
		EndDo;
		If NoFilledRight Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Не заполнено ни одно право доступа.'; en = 'No access rights are set.'; pl = 'Nie określono prawa dostępu.';es_ES = 'Ningún derecho de acceso especificado.';es_CO = 'Ningún derecho de acceso especificado.';tr = 'Erişim hakkı belirlenmedi.';it = 'Nessun permesso di accesso è stato impostato.';de = 'Kein Zugriffsrecht ist angegeben.'"),
				,
				"RightsGroups[" + Format(RowNumber, "NG=0") + "]." + FirstRightName,
				,
				Cancel);
			Return;
		EndIf;
		
		// Checking the filling of users, user groups, access values, and their duplicates.
		// 
		
		// Checking whether the values are filled
		If NOT ValueIsFilled(CurrentRow["User"]) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Не заполнен пользователь или группа.'; en = 'User or group is required.'; pl = 'Nie wprowadzono użytkownika lub grupy.';es_ES = 'Usuario o grupo no está introducido.';es_CO = 'Usuario o grupo no está introducido.';tr = 'Kullanıcı veya grup girilmedi.';it = 'Utente o gruppo è richiesto.';de = 'Benutzer oder Gruppe wurde nicht eingegeben.'"),
				,
				"RightsGroups[" + Format(RowNumber, "NG=0") + "].User",
				,
				Cancel);
			Return;
		EndIf;
		
		// Checking for duplicates.
		Filter = New Structure;
		Filter.Insert("SettingsOwner", CurrentRow["SettingsOwner"]);
		Filter.Insert("User",      CurrentRow["User"]);
		
		If RightsGroups.FindRows(Filter).Count() > 1 Then
			If TypeOf(Filter.User) = Type("CatalogRef.Users") Then
				MessageText = NStr("ru = 'Настройка для пользователя ""%1"" уже есть.'; en = 'Setting for ""%1"" user already exists.'; pl = 'Ustawienie dla użytkownika ""%1"" już istnieje.';es_ES = 'Configuración para el usuario ""%1"" ya existe.';es_CO = 'Configuración para el usuario ""%1"" ya existe.';tr = '""%1"" kullanıcı için ayarlar zaten var.';it = 'Le impostazioni per l''utente ""%1"" già esistono.';de = 'Die Einstellung für den Benutzer ""%1"" existiert bereits.'");
			Else
				MessageText = NStr("ru = 'Настройка для группы пользователей ""%1"" уже есть.'; en = 'Setting for ""%1"" user group already exists.'; pl = 'Ustawienie dla grupy użytkowników ""%1"" już istnieje.';es_ES = 'Configuración para el grupo de usuarios ""%1"" ya existe.';es_CO = 'Configuración para el grupo de usuarios ""%1"" ya existe.';tr = '""%1"" kullanıcı grubu için ayarlar zaten var.';it = 'Le impostazioni per il gruppo utenti ""%1"" già esistono.';de = 'Die Einstellung für die Benutzergruppe ""%1"" existiert bereits.'");
			EndIf;
			CommonClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersToString(MessageText, Filter.User),
				,
				"RightsGroups[" + Format(RowNumber, "NG=0") + "].User",
				,
				Cancel);
			Return;
		EndIf;
			
		RowNumber = RowNumber - 1;
	EndDo;
	
EndProcedure

&AtServer
Procedure WriteRights()
	
	ValidatePermissionToManageRights();
	
	BeginTransaction();
	Try
		SetPrivilegedMode(True);
		InformationRegisters.ObjectsRightsSettings.Write(Parameters.ObjectRef, RightsGroups, InheritParentRights);
		SetPrivilegedMode(False);
		
		If ConfirmRightsManagementCancellation = False
		 Or AccessManagement.HasRight("RightsManagement", Parameters.ObjectRef) Then
			
			Modified = False;
		Else
			ConfirmRightsManagementCancellation = True;
			Raise NStr("ru = 'После записи настройка прав станет недоступной.'; en = 'Rights setting will be disabled after saving.'; pl = 'Po zapisaniu nie można przypisać praw dostępu.';es_ES = 'Después de la grabación, usted no puede asignar los derechos de acceso.';es_CO = 'Después de la grabación, usted no puede asignar los derechos de acceso.';tr = 'Yazdıktan sonra, erişim hakları atayamazsınız.';it = 'Le impostazioni dei permessi saranno disabilitate dopo il salvataggio.';de = 'Nach dem Schreiben können Sie keine Zugriffsrechte zuweisen.'");
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	AccessManagementInternal.AfterChangeRightsSettingsInForm();
	
EndProcedure

&AtClient
Procedure CheckOpportunityToChangeRights(Cancel, DeletionCheck = False)
	
	CurrentSettingOwner = Items.RightsGroups.CurrentData["SettingsOwner"];
	
	If ValueIsFilled(CurrentSettingOwner)
	   AND CurrentSettingOwner <> Parameters.ObjectRef Then
		
		Cancel = True;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Эти права унаследованы, их можно изменить в форме настройки прав
			           |вышестоящей папки ""%1"".'; 
			           |en = 'These rights are inherited. You can changed them in the rights settings form
			           |of the parent folder ""%1"".'; 
			           |pl = 'Te uprawnienia zostały odziedziczone, można je zmienić w formularzu uprawnień
			           |folderu nadrzędnego ""%1"".';
			           |es_ES = 'Estos derechos se han heredado, pueden cambiarse en el formulario de ajuste de derechos
			           |de una carpeta superior ""%1"".';
			           |es_CO = 'Estos derechos se han heredado, pueden cambiarse en el formulario de ajuste de derechos
			           |de una carpeta superior ""%1"".';
			           |tr = 'Bu haklar devralındı, 
			           |üst klasörün hakları %1şeklinde değiştirilebilirler.';
			           |it = 'Questi diritti sono ereditati. È possibile modificarli nel modulo di impostazioni dei diritti
			           |della cartella madre ""%1"".';
			           |de = 'Diese Rechte werden vererbt und können in Form der Einrichtung der Rechte
			           |des übergeordneten Ordners ""%1"" geändert werden.'"),
			CurrentSettingOwner);
		
		If DeletionCheck Then
			MessageText = MessageText + Chars.LF + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Для удаления всех унаследованных прав следует
				           |снять флажок ""%1"".'; 
				           |en = 'To delete all inherited rights,
				           |clear check box ""%1"".'; 
				           |pl = 'Aby usunąć wszystkie odziedziczone prawa należy
				           |usunąć zaznaczenie ""%1"".';
				           |es_ES = 'Para borrar todos los derechos heredados,
				           |quitar la casilla de verificación ""%1"".';
				           |es_CO = 'Para borrar todos los derechos heredados,
				           |quitar la casilla de verificación ""%1"".';
				           |tr = 'Devralınan tüm hakları silmek için
				           |onay kutusunu %1 temizleyin.';
				           |it = 'Per eliminare tutti i diritti ereditati
				           | deselezionare la casella di controllo ""%1"".';
				           |de = 'Um alle vererbten Rechte zu entfernen,
				           |deaktivieren Sie das Kontrollkästchen ""%1"".'"),
				Items.InheritParentRights.Title);
		EndIf;
	EndIf;
	
	If Cancel Then
		ShowMessageBox(, MessageText);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GenerateUserSelectionData(Text)
	
	Return Users.GenerateUserSelectionData(Text);
	
EndFunction

&AtClient
Procedure ShowTypeSelectionUsersOrExternalUsers(ContinuationHandler)
	
	ExternalUsersSelectionAndPickup = False;
	
	If UseExternalUsers Then
		
		UserTypesList.ShowChooseItem(
			New NotifyDescription(
				"ShowTypeSelectionUsersOrExternalUsersCompletion",
				ThisObject,
				ContinuationHandler),
			NStr("ru = 'Выбор типа данных'; en = 'Select data type'; pl = 'Wybierz typ danych';es_ES = 'Seleccionar el tipo de datos';es_CO = 'Seleccionar el tipo de datos';tr = 'Veri türünü seçin';it = 'Selezione del tipo di dati';de = 'Wählen Sie den Datentyp aus'"),
			UserTypesList[0]);
	Else
		ExecuteNotifyProcessing(ContinuationHandler, ExternalUsersSelectionAndPickup);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowTypeSelectionUsersOrExternalUsersCompletion(SelectedItem, ContinuationHandler) Export
	
	If SelectedItem <> Undefined Then
		ExternalUsersSelectionAndPickup =
			SelectedItem.Value = Type("CatalogRef.ExternalUsers");
		
		ExecuteNotifyProcessing(ContinuationHandler, ExternalUsersSelectionAndPickup);
	Else
		ExecuteNotifyProcessing(ContinuationHandler, Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectUsers()
	
	CurrentUser = ?(Items.RightsGroups.CurrentData = Undefined,
		Undefined, Items.RightsGroups.CurrentData.User);
	
	If ValueIsFilled(CurrentUser)
	   AND (    TypeOf(CurrentUser) = Type("CatalogRef.Users")
	      OR TypeOf(CurrentUser) = Type("CatalogRef.UserGroups") ) Then
		
		ExternalUsersSelectionAndPickup = False;
		
	ElsIf UseExternalUsers
	        AND ValueIsFilled(CurrentUser)
	        AND (    TypeOf(CurrentUser) = Type("CatalogRef.ExternalUsers")
	           OR TypeOf(CurrentUser) = Type("CatalogRef.ExternalUsersGroups") ) Then
	
		ExternalUsersSelectionAndPickup = True;
	Else
		ShowTypeSelectionUsersOrExternalUsers(
			New NotifyDescription("SelectUsersCompletion", ThisObject));
		Return;
	EndIf;
	
	SelectUsersCompletion(ExternalUsersSelectionAndPickup, Undefined);
	
EndProcedure

&AtClient
Procedure SelectUsersCompletion(ExternalUsersSelectionAndPickup, Context) Export
	
	If ExternalUsersSelectionAndPickup = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow", ?(
		Items.RightsGroups.CurrentData = Undefined,
		Undefined,
		Items.RightsGroups.CurrentData.User));
	
	If ExternalUsersSelectionAndPickup Then
		FormParameters.Insert("SelectExternalUsersGroups", True);
	Else
		FormParameters.Insert("UsersGroupsSelection", True);
	EndIf;
	
	If ExternalUsersSelectionAndPickup Then
		
		OpenForm(
			"Catalog.ExternalUsers.ChoiceForm",
			FormParameters,
			Items.RightsGroupsUser);
	Else
		OpenForm(
			"Catalog.Users.ChoiceForm",
			FormParameters,
			Items.RightsGroupsUser);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillUserPictureNumbers(RowID = Undefined)
	
	Users.FillUserPictureNumbers(RightsGroups, "User", "PictureNumber", RowID);
	
EndProcedure

&AtServer
Procedure ValidatePermissionToManageRights()
	
	If AccessManagement.HasRight("RightsManagement", Parameters.ObjectRef) Then
		Return;
	EndIf;
	
	Raise NStr("ru = 'Настройка прав недоступна.'; en = 'Rights settings are unavailable.'; pl = 'Ustawienie uprawnień nie jest dostępne.';es_ES = 'Configuración de derechos no se encuentra disponible.';es_CO = 'Configuración de derechos no se encuentra disponible.';tr = 'Hak ayarları mevcut değil.';it = 'Le impostazioni dei diritti non sono disponibili.';de = 'Einstellungsrechte sind nicht verfügbar.'");
	
EndProcedure

#EndRegion
