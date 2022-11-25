#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Users.CommonAuthorizationSettingsUsed() Then
		Items.UsersAuthorizationSettingsGroup.Visible = False;
		Items.ExternalUsersListGroupIndent.Visible = False;
		Items.ExternalUsersAuthorizationSettingsGroup.Visible = False;
		Items.ExternalUsersGroup.Group
			= ChildFormItemsGroup.AlwaysHorizontal;
	EndIf;
	
	If Common.DataSeparationEnabled()
	 Or StandardSubsystemsServer.IsBaseConfigurationVersion()
	 Or Common.IsStandaloneWorkplace()
	 Or Not UsersInternal.ExternalUsersEmbedded() Then
		
		Items.ExternalUsersGroup.Visible = False;
		Items.SectionDetails.Title =
			NStr("ru = 'Администрирование пользователей, настройка групп доступа, управление пользовательскими настройками.'; en = 'User administration, access group setup, custom settings management.'; pl = 'Administracja użytkowników, konfigurowanie grup dostępu, zarządzanie ustawieniami użytkowników.';es_ES = 'La administración de usuarios, ajuste de los grupos del acceso, gestión de los ajustes de usuarios.';es_CO = 'La administración de usuarios, ajuste de los grupos del acceso, gestión de los ajustes de usuarios.';tr = 'Kullanıcı yönetimi, erişim gruplarını yapılandırma, kullanıcı ayarlarını yönetme.';it = 'Amministrazione utenti, impostazioni gruppo di accesso, gestione impostazioni personalizzate.';de = 'Benutzerverwaltung, Konfiguration von Zugriffsgruppen, Verwaltung von Benutzereinstellungen.'");
	EndIf;
	
	If StandardSubsystemsServer.IsBaseConfigurationVersion()
	 Or Common.IsStandaloneWorkplace() Then
		
		Items.UseUserGroups.Enabled = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		SimplifiedInterface = ModuleAccessManagementInternal.SimplifiedAccessRightsSetupInterface();
		Items.OpenAccessGroups.Visible            = NOT SimplifiedInterface;
		Items.UseUserGroups.Visible = NOT SimplifiedInterface;
		Items.AccessUpdateAtRecordLevel.Visible =
			ModuleAccessManagementInternal.LimitAccessAtRecordLevelUniversally(True);
		
		If Common.IsStandaloneWorkplace() Then
			Items.LimitAccessAtRecordLevel.Enabled = False;
		EndIf;
	Else
		Items.AccessGroupsGroup.Visible = False;
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		Items.PeriodClosingDatesGroup.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		Items.OpenPersonalDataAccessEventsRegistrationSettingsGroup.Visible =
			  Not Common.DataSeparationEnabled()
			AND Users.IsFullUser(, True);
	Else
		Items.PersonalDataProtectionGroup.Visible = False;
	EndIf;
	
	// Update items states.
	SetAvailability();
	
	ApplicationSettingsOverridable.UsersAndRightsSettingsOnCreateAtServer(ThisObject);
	
	SetSupportTitle(Constants.DefaultSupport.Get());
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	If Exit Then
		Return;
	EndIf;
	UpdateApplicationInterface();
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName <> "Write_ConstantsSet" Then
		Return;
	EndIf;
	
	If Source = "UseSurvey" 
		AND CommonClient.SubsystemExists("StandardSubsystems.Survey") Then
		
		Read();
		SetAvailability();
		
	ElsIf Source = "UseHidePersonalDataOfSubjects" Then
		Read();
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.SelectBusinessProcessPerformer" Then
		UpdateDefaultSupport(SelectedValue, Undefined);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UseUsersGroupsOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseRecordsLevelSecurityOnChange(Item)
	
	If ConstantsSet.LimitAccessAtRecordLevel Then
		
		QuestionText =
			NStr("ru = 'Включить ограничение доступа на уровне записей?
			           |
			           |Потребуется заполнение данных, которое будет выполняться частями
			           |регламентным заданием ""Заполнение данных для ограничения доступа""
			           |(ход выполнения в журнале регистрации).
			           |
			           |Выполнение может сильно замедлить работу программы и выполняться
			           |от нескольких секунд до многих часов (в зависимости от объема данных).'; 
			           |en = 'Enable access restriction on the record level?
			           |
			           |There will be a data fill-in executed by parts
			           |by the ""Data population for access restriction"" scheduled job
			           |(see the event log for execution progress).
			           |
			           |The execution may slow down the application and take
			           |from several seconds to many hours (depending on the amount of data).'; 
			           |pl = 'Czy chcesz wprowadzić
			           |
			           |ograniczenie dostępu na poziomie zapisów?
			           |Wymagane będą wypełnienie danych, które
			           |będą wykonywane przez części zadań harmonogramu ""Wypełnienie danych dla ograniczenia dostępu"" (krok wykonania w dzienniku wydarzeń).
			           |
			           |Wykonanie może znacznie
			           |spowolnić pracę aplikacji i jest wykonywane od kilku sekund do wielu godzin (w zależności od ilości danych).';
			           |es_ES = '¿Quiere activar
			           |
			           |la restricción de acceso a nivel de grabación?
			           |Se requerirá el relleno de datos que
			           |se ejecutará por las partes de la tarea programada ""Relleno de datos para la restricción de acceso"" (realizar el paso en la pantalla del registro de eventos).
			           |
			           |Ejecución puede en gran parte frenar el
			           |trabajo de la aplicación, y se ejecuta desde varios segundos a muchas horas (dependiendo del volumen de datos).';
			           |es_CO = '¿Quiere activar
			           |
			           |la restricción de acceso a nivel de grabación?
			           |Se requerirá el relleno de datos que
			           |se ejecutará por las partes de la tarea programada ""Relleno de datos para la restricción de acceso"" (realizar el paso en la pantalla del registro de eventos).
			           |
			           |Ejecución puede en gran parte frenar el
			           |trabajo de la aplicación, y se ejecuta desde varios segundos a muchas horas (dependiendo del volumen de datos).';
			           |tr = 'Yazma düzeyindeki 
			           |
			           |erişim kısıtlamasını etkinleştirmek ister misiniz? 
			           |Programlama iş parçaları ""Erişim kısıtlaması için veri doldurma"" (program günlüğü olayında adımı gerçekleştir)
			           | verisinin doldurulması gerekecektir. 
			           |
			           |Yürütme, uygulama işlemlerini büyük ölçüde yavaşlatabilir ve 
			           |birkaç saniye ile birkaç saat arasında gerçekleştirilir (veri hacmine bağlı olarak).';
			           |it = 'Abilita restrizione di accesso a livello di record?
			           |
			           |Ci sarà una compilazione dati eseguita per parti
			           |secondo del processo pianificato ""Restrizioni di compilazione a livello di record""
			           |(vedi il registro eventi per i progessi di esecuzione).
			           |
			           |L''esecuzione potrebbe rallentare l''applicazione e prendere
			           |da pochi secondi a molte ore (a seconda della quantità di dati).';
			           |de = 'Möchten Sie die
			           |Zugriffsbeschränkung für die Schreibstufe aktivieren?
			           |
			           |Es werden Fülldaten benötigt, die von
			           |den Arbeitsplanteilen ""Daten für Zugriffsbeschränkung füllen"" ausgeführt werden (Schritt im Ereignisprotokollmonitor durchführen).
			           |
			           |Die Ausführung kann die
			           |Anwendungsarbeit stark verlangsamen und wird von einigen Sekunden bis zu vielen Stunden ausgeführt (abhängig vom Datenvolumen).'");
		
		ShowQueryBox(
			New NotifyDescription(
				"UseRecordsLevelSecurityOnChangeCompletion",
				ThisObject, Item),
			QuestionText, QuestionDialogMode.YesNo);
	Else
		Attachable_OnChangeAttribute(Item);
		
		If ConstantsSet.UseCounterpartiesAccessGroups Then
			ConstantsSet.UseCounterpartiesAccessGroups = False;
			Attachable_OnChangeAttribute(Items.UseCounterpartiesAccessGroups);
		EndIf;
		
		If ConstantsSet.UseFilesAccessGroups Then
			ConstantsSet.UseFilesAccessGroups = False;
			Attachable_OnChangeAttribute(Items.UseFilesAccessGroups);
		EndIf;
		
		If ConstantsSet.UseProductAccessGroupsForExternalUsers Then
			ConstantsSet.UseProductAccessGroupsForExternalUsers = False;
			Attachable_OnChangeAttribute(Items.UseProductAccessGroupsForExternalUsers);
		EndIf;
		
		If ConstantsSet.UseContractRestrictionsForExternalUsers Then
			ConstantsSet.UseContractRestrictionsForExternalUsers = False;
			Attachable_OnChangeAttribute(Items.UseContractRestrictionsForExternalUsers);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UseExternalUsersOnChange(Item)
	
	If ConstantsSet.UseExternalUsers Then
		
		QuestionText =
			NStr("ru = 'Разрешить доступ внешним пользователям?
			           |
			           |При входе в программу список выбора пользователей станет пустым
			           |(реквизит ""Показывать в списке выбора"" в карточках всех
			           | пользователей будет очищен и скрыт).'; 
			           |en = 'Do you want to allow external user access?
			           |
			           |This will clear the user selection list in the authorization window
			           |(the ""Show in selection list"" attribute will be cleared and hidden from all user profiles).
			           |'; 
			           |pl = 'Czy chcesz zezwolić na dostęp użytkownikom zewnętrznym?
			           |
			           |Po wejściu do programu lista wyboru użytkowników będzie pusta
			           |(atrybut ""Pokaż na liście wyboru"" w kartach wszystkich
			           | użytkowników będzie wyczyszczony i ukryty z profili wszystkich użytkowników)';
			           |es_ES = '¿Permitir el acceso a los usuarios externos?
			           |
			           |Al entrar en el programa la lista de selección de usuarios estará vacía
			           | (el requisito ""Mostrar en la lista de selección"" en las tarjetas de todos los
			           | usuarios será limpiado y ocultado).';
			           |es_CO = '¿Permitir el acceso a los usuarios externos?
			           |
			           |Al entrar en el programa la lista de selección de usuarios estará vacía
			           | (el requisito ""Mostrar en la lista de selección"" en las tarjetas de todos los
			           | usuarios será limpiado y ocultado).';
			           |tr = 'Harici kullanıcılara erişime izin ver? 
			           |
			           |Programa girdiğinizde, kullanıcı seçimi listesi boş olur 
			           |(tüm 
			           |kullanıcıların kartlarında ""Seçim listesinde göster"" ayrıntıları temizlenir ve gizlenir).';
			           |it = 'Vuoi consentire l''accesso di utenti esterni?
			           |
			           |Questa azione cancellerà l''elenco degli utenti nella finestra di autorizzazione
			           |(il requisito ""Mostra nell''elenco di selezione"" sarà cancellato e nascosto da tutti i profili utente).
			           |';
			           |de = 'Zugriff für externe Benutzer erlauben?
			           |
			           |Wenn Sie das Programm aufrufen, wird die Benutzerauswahlliste leer
			           |(das Attribut ""In Auswahlliste anzeigen"" in den Benutzerprofilen wird gelöscht und ausgeblendet).
			           |'");
		
		ShowQueryBox(
			New NotifyDescription(
				"UseExternalUsersOnChangeCompletion",
				ThisObject,
				Item),
			QuestionText,
			QuestionDialogMode.YesNo);
	Else
		QuestionText =
			NStr("ru = 'Запретить доступ внешним пользователям?
			           |
			           |Реквизит ""Вход в программу разрешен"" будет
			           |очищен в карточках всех внешних пользователей.'; 
			           |en = 'Do you want to deny external user access?
			           |
			           |This will clear the ""Can sign in"" attribute 
			           |in all external user profiles.'; 
			           |pl = 'Uniemożliwić dostęp użytkownikom zewnętrznym?
			           |
			           |Rekwizyty ""Logowanie do programu dozwolone"" będzie
			           |wyczyszczony w kartach wszystkich użytkowników zewnętrznych.';
			           |es_ES = '¿Prohibir acceder a los usuarios externos?
			           |
			           |El requisito ""Está permitido entrar en el programa"" será
			           |limpiado en las tarjetas de todos los usuarios externos.';
			           |es_CO = '¿Prohibir acceder a los usuarios externos?
			           |
			           |El requisito ""Está permitido entrar en el programa"" será
			           |limpiado en las tarjetas de todos los usuarios externos.';
			           |tr = 'Harici kullanıcıların erişimini engelle? 
			           |
			           |""Programa girişine izin verilir"" sahne tüm dış kullanıcıların kartlarında 
			           |temizlenecektir.';
			           |it = 'Vuoi impedire l''accesso di utenti esterni?
			           |
			           |Questa azione cancellerà il requisito ""Puoi accedere""
			           |in tutti i profili di utenti esterni.';
			           |de = 'Zugriff für externe Benutzer verweigern?
			           |
			           |Das Attribut ""Login in das Programm ist erlaubt"" wird
			           |in allen externen Benutzerprofilen gelöscht.'");
		
		ShowQueryBox(
			New NotifyDescription(
				"UseExternalUsersOnChangeCompletion",
				ThisObject,
				Item),
			QuestionText,
			QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

&AtClient
Procedure UseCounterpartiesAccessGroupsOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure UseFileAccessGroupsOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure UseProductAccessGroupsForExternalUsersOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure UseContractRestrictionsForExternalUsersOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CatalogExternalUsers(Command)
	OpenForm("Catalog.ExternalUsers.ListForm", , ThisObject);
EndProcedure

&AtClient
Procedure ExternalUsersAuthorizationSettings(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ShowExternalUsersSettings", True);
	
	OpenForm("CommonForm.UserAuthorizationSettings", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure AccessUpdateAtRecordLevel(Command)
	
	OpenForm("InformationRegister" + "." + "DataAccessKeysUpdate" + "."
		+ "Form" + "." + "AccessUpdateAtRecordLevel");
	
EndProcedure

&AtClient
Procedure CounterpartyAccessGroups(Command)
	
	OpenForm("Catalog.CounterpartiesAccessGroups.ListForm", , ThisObject);
	
EndProcedure

&AtClient
Procedure FilesAccessGroups(Command)
	
	OpenForm("Catalog.FilesAccessGroups.ListForm", , ThisObject);
	
EndProcedure

&AtClient
Procedure Support(Command)
	
	If GetConstantData("UseBusinessProcessesAndTasks") Then
		
		Notification = New NotifyDescription("UpdateDefaultSupport", ThisObject);
		
		OpenForm("Constant.DefaultSupport.ConstantsForm", , ThisObject, , , , Notification);
		
	Else
		SetAvailability();
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductAccessGroups(Command)
	
	OpenForm("Catalog.ProductAccessGroupsForExternalUsers.ListForm", , ThisObject);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure Attachable_OnChangeAttribute(Item, UpdateInterface = True)
	
	ConstantsNamesArray = OnChangeAttributeServer(Item.Name);
	
	RefreshReusableValues();
	
	If UpdateInterface Then
		RefreshInterface = True;
		AttachIdleHandler("UpdateApplicationInterface", 2, True);
	EndIf;
	
	For Each ConstantName In ConstantsNamesArray Do
		If ConstantName <> "" Then
			Notify("Write_ConstantsSet", New Structure, ConstantName);
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure Attachable_PDHidingSettingsOnChange(Item)
	
	If CommonClient.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		ModulePersonalDataProtectionClient = CommonClient.CommonModule("PersonalDataProtectionClient");
		ModulePersonalDataProtectionClient.OnChangePersonalDataHidingSettings(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		CommonClient.RefreshApplicationInterface();
	EndIf;
	
EndProcedure

&AtClient
Procedure UseRecordsLevelSecurityOnChangeCompletion(Response, Item) Export
	
	If Response = DialogReturnCode.No Then
		ConstantsSet.LimitAccessAtRecordLevel = False;
	Else
		Attachable_OnChangeAttribute(Item);
	EndIf;
	
EndProcedure

&AtClient
Procedure UseExternalUsersOnChangeCompletion(Response, Item) Export
	
	If Response = DialogReturnCode.No Then
		ConstantsSet.UseExternalUsers = Not ConstantsSet.UseExternalUsers;
	Else
		Attachable_OnChangeAttribute(Item);
		
		If ConstantsSet.UseProductAccessGroupsForExternalUsers Then
			ConstantsSet.UseProductAccessGroupsForExternalUsers = False;
			Attachable_OnChangeAttribute(Items.UseProductAccessGroupsForExternalUsers);
		EndIf;
		
		If ConstantsSet.UseContractRestrictionsForExternalUsers Then
			ConstantsSet.UseContractRestrictionsForExternalUsers = False;
			Attachable_OnChangeAttribute(Items.UseContractRestrictionsForExternalUsers);
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server call

&AtServer
Function OnChangeAttributeServer(ItemName)
	
	ConstantsNamesArray = New Array;
	
	DataPathAttribute = Items[ItemName].DataPath;
	
	BeginTransaction();
	Try
		
		ConstantName = SaveAttributeValue(DataPathAttribute);
		ConstantsNamesArray.Add(ConstantName);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	SetAvailability(DataPathAttribute);
	
	RefreshReusableValues();
	
	Return ConstantsNamesArray;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServerNoContext
Function GetConstantData(ConstantName)
	Return Constants[ConstantName].Get();
EndFunction 

&AtServer
Function SaveAttributeValue(DataPathAttribute)
	
	// Save values of attributes not directly related to constants (in ratio one to one).
	If DataPathAttribute = "" Then
		Return "";
	EndIf;
	
	// Define the constant name.
	ConstantName = "";
	Position = StrFind(DataPathAttribute, "ConstantsSet.");
	If Position > 0 Then
		ConstantName = StrReplace(DataPathAttribute, "ConstantsSet.", "");
	Else
		// Define the name and record the attribute value in the constant from the ConstantsSet.
		// It is used for those form attributes that are directly related to constants (in ratio one to one).
	EndIf;
	
	// Save the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		CurrentValue  = ConstantManager.Get();
		
		If CurrentValue <> ConstantValue Then
			Try
				ConstantManager.Set(ConstantValue);
			Except
				ConstantsSet[ConstantName] = CurrentValue;
				Raise;
			EndTry;
		EndIf;
	EndIf;
	
	Return ConstantName;
	
EndFunction

&AtServer
Procedure SetAvailability(DataPathAttribute = "")
	
	If DataPathAttribute = "ConstantsSet.UseExternalUsers"
	 Or DataPathAttribute = "" Then
		
		UseExternalUsers = ConstantsSet.UseExternalUsers;
		
		Items.OpenExternalUsers.Enabled					 = UseExternalUsers;
		Items.ExternalUsersAuthorizationSettings.Enabled = UseExternalUsers;
		Items.Support.Enabled							 = UseExternalUsers;
		Items.OpenAccessGroups.Visible					 = UseExternalUsers;
		Items.UseProductAccessGroupsForExternalUsers.Enabled = (ConstantsSet.LimitAccessAtRecordLevel
																And UseExternalUsers);
		Items.UseContractRestrictionsForExternalUsers.Enabled = (ConstantsSet.LimitAccessAtRecordLevel
																And UseExternalUsers);
		SetAvailability("ConstantsSet.UseProductAccessGroupsForExternalUsers");
		SetAvailability("ConstantsSet.UseContractRestrictionsForExternalUsers");
		
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates")
		And (DataPathAttribute = "ConstantsSet.UsePeriodClosingDates"
		Or DataPathAttribute = "") Then
		
		Items.PeriodClosingDatesSettingGroup.Enabled =
			ConstantsSet.UsePeriodClosingDates;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement")
		And (DataPathAttribute = "ConstantsSet.LimitAccessAtRecordLevel"
		Or DataPathAttribute = "") Then
		
		Items.AccessUpdateAtRecordLevel.Enabled = ConstantsSet.LimitAccessAtRecordLevel;
		Items.UseCounterpartiesAccessGroups.Enabled = ConstantsSet.LimitAccessAtRecordLevel;
		Items.UseFilesAccessGroups.Enabled = ConstantsSet.LimitAccessAtRecordLevel;
		Items.UseProductAccessGroupsForExternalUsers.Enabled = (ConstantsSet.LimitAccessAtRecordLevel
																And ConstantsSet.UseExternalUsers);
		Items.UseContractRestrictionsForExternalUsers.Enabled = (ConstantsSet.LimitAccessAtRecordLevel
																And ConstantsSet.UseExternalUsers);
		
		SetAvailability("ConstantsSet.UseCounterpartiesAccessGroups");
		SetAvailability("ConstantsSet.UseFilesAccessGroups");
		SetAvailability("ConstantsSet.UseProductAccessGroupsForExternalUsers");
		SetAvailability("ConstantsSet.UseContractRestrictionsForExternalUsers");
		
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement")
		And (DataPathAttribute = "ConstantsSet.UseCounterpartiesAccessGroups"
		Or DataPathAttribute = "") Then
		
		Items.CounterpartyAccessGroups.Enabled = ConstantsSet.UseCounterpartiesAccessGroups;
		
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement")
		And (DataPathAttribute = "ConstantsSet.UseFilesAccessGroups"
		Or DataPathAttribute = "") Then
		
		Items.FilesAccessGroups.Enabled = ConstantsSet.UseFilesAccessGroups;
		
	EndIf;
	
	If Not Constants.UseBusinessProcessesAndTasks.Get() Then
		Items.Support.Enabled = False;
		Items.SupportExtendedTooltip.Title = NStr("en = 'Set up default support (enabled only if Tasks are allowed)'; ru = 'Настройка поддержки по умолчанию (доступно, если разрешены задачи)';pl = 'Ustaw domyślną pomoc techniczną (dostępne, jeśli dozwolone są Zadania)';es_ES = 'Configurar la ayuda por defecto (habilitado sólo si se permiten las Tareas)';es_CO = 'Configurar la ayuda por defecto (habilitado sólo si se permiten las Tareas)';tr = 'Varsayılan desteği ayarla (Görevlere izin verildiyse etkindir)';it = 'Impostare supporto predefinito (attivato solo se Compiti è concesso)';de = 'Standardunterstützung festlegen (aktiviert nur bei gestatteten Aufgaben)'");
	EndIf;
	
	If (DataPathAttribute = "ConstantsSet.UseProductAccessGroupsForExternalUsers"
		Or DataPathAttribute = "") Then
		
		Items.ProductAccessGroups.Enabled = ConstantsSet.UseProductAccessGroupsForExternalUsers;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetSupportTitle(Value)
	
	If Not ValueIsFilled(Value) Then
		Items.Support.Title = NStr("en = 'Support: <Empty>'; ru = 'Поддержка: <пусто>';pl = 'Pomoc techniczna: <Pusto>';es_ES = 'Ayuda: <Vacío>';es_CO = 'Ayuda: <Vacío>';tr = 'Destek: <Boş>';it = 'Supporto <Vuoto>';de = 'Unterstützung: <Leer>'");
	Else
		Items.Support.Title = StrTemplate(NStr("en = 'Support: %1'; ru = 'Поддержка: %1';pl = 'Pomoc techniczna: %1';es_ES = 'Ayuda: %1';es_CO = 'Ayuda: %1';tr = 'Destek: %1';it = 'Supporto: %1';de = 'Unterstützung: %1'"), Value);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateDefaultSupport(Result, AdditionalParameters) Export
	
	ConstantValue = Constants.DefaultSupport.Get();
	Constants.UseSupportForExternalUsers.Set(ConstantValue <> Undefined And ValueIsFilled(ConstantValue));
	
	SetSupportTitle(ConstantValue);
	
EndProcedure

#EndRegion
