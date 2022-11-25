
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	SetOrder();
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ReadOnly = True;
	
	PeriodClosingDatesInternal.UpdatePeriodClosingDatesSections();
	
	// Setting up the command.
	SectionsProperties = PeriodClosingDatesInternal.SectionsProperties();
	Items.FormDataImportRestrictionDates.Visible = SectionsProperties.ImportRestrictionDatesImplemented;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	Cancel = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure PeriodEndClosingDates(Command)
	
	OpenForm("InformationRegister.PeriodClosingDates.Form.PeriodClosingDates");
	
EndProcedure

&AtClient
Procedure DataImportRestrictionDates(Command)
	
	FormParameters = New Structure("DataImportRestrictionDates", True);
	OpenForm("InformationRegister.PeriodClosingDates.Form.PeriodClosingDates", FormParameters);
	
EndProcedure

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	List.SettingsComposer.Settings.ConditionalAppearance.Items.Clear();
	
	For Each UserType In Metadata.InformationRegisters.PeriodClosingDates.Dimensions.User.Type.Types() Do
		MetadataObject = Metadata.FindByType(UserType);
		If NOT Metadata.ExchangePlans.Contains(MetadataObject) Then
			Continue;
		EndIf;
		
		ApplyAppearanceValue(Common.ObjectManagerByFullName(MetadataObject.FullName()).EmptyRef(),
			MetadataObject.Presentation() + ": " + NStr("ru = '<Все информационные базы>'; en = '<All infobases>'; pl = '<Wszystkie bazy informacyjne>';es_ES = '<Todas infobases>';es_CO = '<All infobases>';tr = '<Tüm bilgi tabanları>';it = '<Tutti gli infobase>';de = 'Alle Datenbanken'"));
	EndDo;
	
	ApplyAppearanceValue(Undefined,
		NStr("ru = 'Неопределено'; en = 'Undefined'; pl = 'Nieokreślone';es_ES = 'No definido';es_CO = 'No definido';tr = 'Tanımlanmamış';it = 'Non definito';de = 'Nicht definiert'"));
	
	ApplyAppearanceValue(Catalogs.Users.EmptyRef(),
		NStr("ru = 'Пустой пользователь'; en = 'Empty user'; pl = 'Pusty użytkownik';es_ES = 'Usuario vacío';es_CO = 'Usuario vacío';tr = 'Boş kullanıcı';it = 'Utente non inserito';de = 'Leerer Benutzer'"));
	
	ApplyAppearanceValue(Catalogs.UserGroups.EmptyRef(),
		NStr("ru = 'Пустая группа пользователей'; en = 'Empty user group'; pl = 'Pusta grupa użytkowników';es_ES = 'Grupo de usuarios vacíos';es_CO = 'Grupo de usuarios vacíos';tr = 'Boş kullanıcı grubu';it = 'Gruppo di utenti non inserito';de = 'Leere Benutzergruppe'"));
	
	ApplyAppearanceValue(Catalogs.ExternalUsers.EmptyRef(),
		NStr("ru = 'Пустой внешний пользователь'; en = 'Empty external user'; pl = 'Pusty użytkownik zewnętrzny';es_ES = 'Usuario externo vacío';es_CO = 'Usuario externo vacío';tr = 'Boş harici kullanıcı';it = 'Utente esterno non inserito';de = 'Leerer externer Benutzer'"));
	
	ApplyAppearanceValue(Catalogs.ExternalUsersGroups.EmptyRef(),
		NStr("ru = 'Пустая группа внешних пользователей'; en = 'Empty external user group'; pl = 'Pusta grupa użytkowników zewnętrznych';es_ES = 'Grupo de usuarios externos vacíos';es_CO = 'Grupo de usuarios externos vacíos';tr = 'Boş harici kullanıcı grubu';it = 'Gruppo di utenti esterni non inserito';de = 'Leere externe Benutzergruppe'"));
	
	ApplyAppearanceValue(Enums.PeriodClosingDatesPurposeTypes.ForAllUsers,
		"<" + Enums.PeriodClosingDatesPurposeTypes.ForAllUsers + ">");
	
	ApplyAppearanceValue(Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases,
		"<" + Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases + ">");
	
EndProcedure

&AtServer
Procedure ApplyAppearanceValue(Value, Text)
	
	AppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	AppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	AppearanceItem.Appearance.SetParameterValue("Text", Text);
	
	FilterItem = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("User");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = Value;
	
	FieldItem = AppearanceItem.Fields.Items.Add();
	FieldItem.Field = New DataCompositionField("User");
	
EndProcedure

&AtServer
Procedure SetOrder()
	
	Order = List.SettingsComposer.Settings.Order;
	Order.Items.Clear();
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Field = New DataCompositionField("User");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Field = New DataCompositionField("Section");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.Use = True;
	
	OrderItem = Order.Items.Add(Type("DataCompositionOrderItem"));
	OrderItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	OrderItem.Field = New DataCompositionField("Object");
	OrderItem.OrderType = DataCompositionSortDirection.Asc;
	OrderItem.Use = True;
	
EndProcedure

#EndRegion
