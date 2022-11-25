
#Region Variables

&AtClient
Var UsersContinueAdding, SelectedUser, SelectedMethodOfPeriodEndClosingDateIndication;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	PeriodClosingDatesInternal.UpdatePeriodClosingDatesSections();
	
	If ClientApplication.CurrentInterfaceVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		InterfaceVersion82 = True;
		Items.UsersAdd.OnlyInAllActions = False;
		Items.ClosingDatesAdd.OnlyInAllActions = False;
	EndIf;
	
	// Caching the current date on the server.
	BegOfDay = BegOfDay(CurrentSessionDate());
	
	// Fill in section properties.
	SectionsProperties = PeriodClosingDatesInternal.SectionsProperties();
	FillPropertyValues(ThisObject, SectionsProperties);
	Table = New ValueTable;
	Table.Columns.Add("Ref", New TypeDescription("ChartOfCharacteristicTypesRef.PeriodClosingDatesSections"));
	Table.Columns.Add("Presentation", New TypeDescription("String",,,, New StringQualifiers(150)));
	Table.Columns.Add("IsCommonDate",  New TypeDescription("Boolean"));
	For Each Section In Sections Do
		If TypeOf(Section.Key) = Type("String") Then
			Continue;
		EndIf;
		NewRow = Table.Add();
		FillPropertyValues(NewRow, Section.Value);
		If Not ValueIsFilled(Section.Value.Ref) Then
			NewRow.Presentation = CommonDatePresentationText();
			NewRow.IsCommonDate  = True;
		EndIf;
	EndDo;
	SectionsTableAddress = PutToTempStorage(Table, UUID);
	
	// Prepare the table for setting or removing form locks.
	Dimensions = Metadata.InformationRegisters.PeriodClosingDates.Dimensions;
	Table = New ValueTable;
	Table.Columns.Add("Section",       Dimensions.Section.Type);
	Table.Columns.Add("Object",       Dimensions.Object.Type);
	Table.Columns.Add("User", Dimensions.User.Type);
	Locks = New Structure;
	Locks.Insert("FormID",   UUID);
	Locks.Insert("Content",               Table);
	Locks.Insert("BegOfDay",            BegOfDay);
	Locks.Insert("NoSectionsAndObjects", NoSectionsAndObjects);
	Locks.Insert("SectionEmptyRef",   SectionEmptyRef);
	
	LocksAddress = PutToTempStorage(Locks, UUID);
	
	// Form field setting
	If Parameters.DataImportRestrictionDates Then
		
		If Not SectionsProperties.ImportRestrictionDatesImplemented Then
			Raise PeriodClosingDatesInternal.ErrorTextImportRestrictionDatesNotImplemented();
		EndIf;
		
		If Not Users.IsFullUser() Then
			Raise NStr("ru = 'Недостаточно прав для работы с датами запрета загрузки.'; en = 'Insufficient rights to operate with data import restriction dates.'; pl = 'Niewystarczające uprawnienia do pracy z datami zakazu pobierania.';es_ES = 'Insuficientes derechos para trabajar con las fechas de restricción de la carga.';es_CO = 'Insuficientes derechos para trabajar con las fechas de restricción de la carga.';tr = 'İçe aktarma yasağı tarihleri ile çalışmak için yetki yetersizdir.';it = 'Diritti insufficienti per operare con le date di limitazione dell''importazione dei dati.';de = 'Unzureichende Rechte zur Arbeit mit Download-Verbotszeiten.'");
		EndIf;
		
		Items.ClosingDatesUsageDisabledLabel.Title =
			NStr("ru = 'Даты запрета загрузки данных прошлых периодов из других программ отключены в настройках.'; en = 'Data import restriction dates of previous periods from other applications are disabled in the settings.'; pl = 'Daty zakazu pobierania danych z poprzednich programów z innych programów są wyłączone w ustawieniach.';es_ES = 'Las fechas de restricción de la carga de los datos de los períodos anteriores de otros programas están desactivadas en los ajustes.';es_CO = 'Las fechas de restricción de la carga de los datos de los períodos anteriores de otros programas están desactivadas en los ajustes.';tr = 'Diğer programlardan geçmiş dönemlerin veri içe aktarılmasını yasaklayan tarihler ayarlarda devre dışı bırakıldı.';it = 'Le date del divieto di download dei dati di precedenti periodi da altri programmi sono disabilitate nelle impostazioni.';de = 'Das Datum des Verbots des Herunterladens früherer Daten aus anderen Programmen ist in den Einstellungen deaktiviert.'");
		
		Title = NStr("ru = 'Даты запрета загрузки данных'; en = 'Data import restriction dates'; pl = 'Daty zakazu importu danych';es_ES = 'Fechas de cierre de la importación de datos';es_CO = 'Fechas de cierre de la importación de datos';tr = 'Verilerin içe aktarılmasına kapatıldığı tarihler';it = 'Date di restrizione importazione dati';de = 'Abschlussdaten des Datenimports'");
		Items.SetPeriodEndClosingDate.ChoiceList.FindByValue("NoPeriodEnd").Presentation =
			NStr("ru = 'Не установлено'; en = 'Not set'; pl = 'Nieustawiony';es_ES = 'No definido';es_CO = 'No definido';tr = 'Belirlenmedi';it = 'Non impostato';de = 'Nicht eingestellt'");
		Items.SetPeriodEndClosingDate.ChoiceList.FindByValue("ForAllUsers").Presentation =
			NStr("ru = 'Для всех информационных баз'; en = 'For all infobases'; pl = 'Dla wszystkich baz informacyjnych';es_ES = 'Para todas infobases';es_CO = 'Para todas infobases';tr = 'Tüm veritabanları için';it = 'Per tutti i database di informazioni';de = 'Für alle Infobases'");
		Items.SetPeriodEndClosingDate.ChoiceList.FindByValue("ByUsers").Presentation =
			NStr("ru = 'По информационным базам'; en = 'By infobases'; pl = 'Wg baz informacyjnych';es_ES = 'Por infobases';es_CO = 'Por infobases';tr = 'Veritabanlarına göre';it = 'Secondo base informativa';de = 'Durch Infobases'");
		
		Items.UsersFullPresentation.Title =
			NStr("ru = 'Программа: информационная база'; en = 'Application: infobase'; pl = 'Aplikacja: baza informacyjna';es_ES = 'Aplicación: infobase';es_CO = 'Aplicación: infobase';tr = 'Uygulama: veri tabanı';it = 'Programma: database informazioni';de = 'Anwendung: Infobase'");
		
		ValueForAllUsers = Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases;
		
		UserTypes =
			Metadata.InformationRegisters.PeriodClosingDates.Dimensions.User.Type.Types();
		
		For Each UserType In UserTypes Do
			MetadataObject = Metadata.FindByType(UserType);
			If Not Metadata.ExchangePlans.Contains(MetadataObject) Then
				Continue;
			EndIf;
			EmptyRefOfExchangePlanNode = Common.ObjectManagerByFullName(
				MetadataObject.FullName()).EmptyRef();
			
			UserTypesList.Add(
				EmptyRefOfExchangePlanNode, MetadataObject.Presentation());
		EndDo;
		Items.Users.RowsPicture = PictureLib.IconsExchangePlanNode;
		
		URL =
			"e1cib/command/InformationRegister.PeriodClosingDates.Command.DataImportRestrictionDates";
	Else
		If Not AccessRight("Edit", Metadata.InformationRegisters.PeriodClosingDates)
		 Or Not AccessRight("View", Metadata.ChartsOfCharacteristicTypes.PeriodClosingDatesSections) Then
			Raise NStr("ru = 'Недостаточно прав для работы с датами запрета изменения.'; en = 'Insufficient rights to operate with period-end closing dates.'; pl = 'Niewystarczające uprawnienia do pracy z datami zakazu zmiany.';es_ES = 'Insuficientes derechos para trabajar con las fechas de restricción del cambio.';es_CO = 'Insuficientes derechos para trabajar con las fechas de restricción del cambio.';tr = 'Dönem sonu kapanış tarihleriyle çalışmak için yetkiler yetersiz.';it = 'Diritti insufficienti per operare con le date di chiusura di fine periodo.';de = 'Unzureichende Rechte auf Arbeit mit Daten des Änderungsverbots.'");
		EndIf;
		
		Items.ClosingDatesUsageDisabledLabel.Title =
			NStr("ru = 'Даты запрета ввода и редактирования данных прошлых периодов отключены в настройках программы.'; en = 'Dates of restriction of entering and editing previous period data are disabled in the application settings.'; pl = 'Daty zakazu wprowadzania i edycji danych poprzednich okresów są wyłączone w ustawieniach programu.';es_ES = 'Las fechas de restricción de introducir y editar los datos de los períodos anteriores están desactivadas en los ajustes del programa.';es_CO = 'Las fechas de restricción de introducir y editar los datos de los períodos anteriores están desactivadas en los ajustes del programa.';tr = 'Geçmiş dönemlere ait verilerin son giriş ve düzenlenmesinin tarihleri program ayarlarında devre dışı bırakıldı.';it = 'Le date di restrizione di inserimento e modifica dei periodi precedenti sono disabilitate nelle impostazioni dell''applicazione.';de = 'Die Termine für das Verbot der Eingabe und Bearbeitung von Altdaten sind in den Programmeinstellungen deaktiviert.'");
		
		ValueForAllUsers = Enums.PeriodClosingDatesPurposeTypes.ForAllUsers;
		
		UserTypesList.Add(
			Type("CatalogRef.Users"),        NStr("ru = 'Пользователь'; en = 'User'; pl = 'Użytkownik';es_ES = 'Usuario';es_CO = 'Usuario';tr = 'Kullanıcı';it = 'Utente';de = 'Benutzer'"));
		
		UserTypesList.Add(
			Type("CatalogRef.ExternalUsers"), NStr("ru = 'Внешний пользователь'; en = 'External user'; pl = 'Użytkownik zewnętrzny';es_ES = 'Usuario externo';es_CO = 'Usuario externo';tr = 'Harici kullanıcı';it = 'Utente esterno';de = 'Externer Benutzer'"));
		
		URL =
			"e1cib/command/InformationRegister.PeriodClosingDates.Command.PeriodEndClosingDates";
	EndIf;
	
	List = Items.PeriodEndClosingDateSettingMethod.ChoiceList;
	
	If NoSectionsAndObjects Then
		Items.PeriodEndClosingDateSettingMethod.Visible =
			ValueIsFilled(CurrentIndicationMethodOfPeriodEndClosingDate(
				"*", SingleSection, ValueForAllUsers, BegOfDay));
		
		List.Delete(List.FindByValue("BySectionsAndObjects"));
		List.Delete(List.FindByValue("BySections"));
		List.Delete(List.FindByValue("ByObjects"));
		
	ElsIf Not ShowSections Then
		List.Delete(List.FindByValue("BySectionsAndObjects"));
		List.Delete(List.FindByValue("BySections"));
	ElsIf AllSectionsWithoutObjects Then
		List.Delete(List.FindByValue("BySectionsAndObjects"));
		List.Delete(List.FindByValue("ByObjects"));
	Else
		List.Delete(List.FindByValue("ByObjects"));
	EndIf;
	
	UseExternalUsers = UseExternalUsers
		AND ExternalUsers.UseExternalUsers();
	
	CatalogExternalUsersAvailable =
		AccessRight("View", Metadata.Catalogs.ExternalUsers);
	
	UpdateAtServer();
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(
		ThisObject, "CurrentUserPresentation");
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName)
	   = Upper("InformationRegister.PeriodClosingDates.Form.PeriodEndClosingDateEdit") Then
		
		If SelectedValue <> Undefined Then
			SelectedRows = Items.ClosingDates.SelectedRows;
			
			For Each SelectedRow In SelectedRows Do
				Row = ClosingDates.FindByID(SelectedRow);
				Row.PeriodEndClosingDateDetails              = SelectedValue.PeriodEndClosingDateDetails;
				Row.PermissionDaysCount         = SelectedValue.PermissionDaysCount;
				Row.PeriodEndClosingDate                      = SelectedValue.PeriodEndClosingDate;
				WriteDetailsAndPeriodEndClosingDate(Row);
				Row.PeriodEndClosingDateDetailsPresentation = DetailsPresentationOfPeriodEndClosingDate(Row);
			EndDo;
			UpdateClosingDatesAvailabilityOfCurrentUser();
		EndIf;
		
		// Cancel lock of selected rows.
		UnlockAllRecordsAtServer(LocksAddress);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If Upper(EventName) <> Upper("Write_ConstantsSet") Then
		Return;
	EndIf;
	
	If Upper(Source) = Upper("UseImportForbidDates")
	 Or Upper(Source) = Upper("UsePeriodClosingDates") Then
		
		AttachIdleHandler("OnChangeOfRestrictionDatesUsage", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	QuestionText = NotificationTextOfUnusedSettingModes();
	If Not ValueIsFilled(QuestionText) Then
		Return;
	EndIf;
	
	QuestionText = NStr("ru = 'Заданные настройки дат запрета будут автоматически скорректированы.'; en = 'The specified settings of period-end closing dates will be adjusted automatically.'; pl = 'Określone ustawienia daty zakazu zostaną automatycznie dostosowane.';es_ES = 'Los ajustes establecidos de restricción serán automáticamente corregidos.';es_CO = 'Los ajustes establecidos de restricción serán automáticamente corregidos.';tr = 'Belirtilen dönem sonu kapanış tarihi ayarları otomatik olarak düzeltilecek.';it = 'Le impostazioni specificate delle date di chiusura di fine periodo saranno regolate automaticamente.';de = 'Die voreingestellten Einstellungen für das Verbotsdatum werden automatisch korrigiert.'") 
		+ Chars.LF + Chars.LF + QuestionText + Chars.LF + Chars.LF + NStr("ru = 'Закрыть?'; en = 'Close?'; pl = 'Chcesz zamknąć?';es_ES = '¿Cerrar?';es_CO = '¿Cerrar?';tr = 'Kapatılsın mı?';it = 'Chiudi';de = 'Schließen?'");
	CommonClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, Exit, QuestionText, "CloseFormWithoutConfirmation");
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	UnlockAllRecordsAtServer(LocksAddress);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure OnChangeOfRestrictionDatesUsage()
	
	OnChangeOfRestrictionDatesUsageAtServer();
	
EndProcedure

&AtServer
Procedure OnChangeOfRestrictionDatesUsageAtServer()
	
	Items.ClosingDatesUsage.CurrentPage = ?(Parameters.DataImportRestrictionDates
		AND Not Constants.UseImportForbidDates.Get()
		Or Not Parameters.DataImportRestrictionDates
		AND Not Constants.UsePeriodClosingDates.Get(), 
		Items.Disabled, Items.Enabled);
	
EndProcedure

&AtClient
Procedure SetPeriodEndClosingDateOnChange(Item)
	
	SelectedValue = SetPeriodEndClosingDateNew;
	If SetPeriodEndClosingDate = SelectedValue Then
		Return;
	EndIf;
	
	CurrentSettingOfPeriodEndClosingDate = CurrentSettingOfPeriodEndClosingDate(Parameters.DataImportRestrictionDates);
	
	If CurrentSettingOfPeriodEndClosingDate = "ByUsers"
	   AND SelectedValue = "ForAllUsers" Then
		
		QuestionText = NStr("ru = 'Отключить все даты запрета, кроме установленных для всех пользователей?'; en = 'Do you want to disable all period-end closing dates except for those set for all users?'; pl = 'Chcesz odłączyć wszystkie daty zakazu, z wyjątkiem tych, ustawionych dla wszystkich użytkowników?';es_ES = 'Desactivar todas las fechas de restricción excepto las instaladas para todos los usuarios?';es_CO = 'Desactivar todas las fechas de restricción excepto las instaladas para todos los usuarios?';tr = 'Tüm kullanıcılar için belirlenenler dışındaki tüm dönem sonu kapanış tarihleri devre dışı bırakılsın mı?';it = 'Disattivare tutte le date di chiusura di fine periodo ad eccezione di quelle impostate per tutti gli utenti?';de = 'Alle Verbotsdaten außer den für alle Benutzer festgelegten deaktivieren?'");
		
	ElsIf (CurrentSettingOfPeriodEndClosingDate = "ByUsers" Or CurrentSettingOfPeriodEndClosingDate = "ForAllUsers")
	        AND SelectedValue = "NoPeriodEnd" Then
		
		QuestionText = NStr("ru = 'Отключить все установленные даты запрета?'; en = 'Do you want to disable all set period-end closing dates?'; pl = 'Chcesz odłączyć wszystkie ustawione daty zakazu?';es_ES = '¿Desactivar todas las fechas de restricción establecidas?';es_CO = '¿Desactivar todas las fechas de restricción establecidas?';tr = 'Ayarlanan tüm dönem sonu kapanış tarihleri devre dışı bırakılsın mı?';it = 'Disattivare tutte le date di chiusura di fine periodo impostate?';de = 'Alle festgelegten Verbotsdaten deaktivieren?'")
		
	EndIf;
	
	If ValueIsFilled(QuestionText) Then
		ShowQueryBox(
			New NotifyDescription(
				"SetPeriodEndClosingDateChoiceProcessingContinue", ThisObject, SelectedValue),
			QuestionText,
			QuestionDialogMode.YesNo);
	Else
		SetPeriodEndClosingDate = SelectedValue;
		ChangeSettingOfPeriodEndClosingDate(SelectedValue, False);
	EndIf;
	
EndProcedure

&AtClient
Procedure IndicationMethodOfPeriodEndClosingDateClear(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure IndicationMethodOfPeriodEndClosingDateChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If PeriodEndClosingDateSettingMethod = ValueSelected Then
		Return;
	EndIf;
	
	SelectedMethodOfPeriodEndClosingDateIndication = ValueSelected;
	
	AttachIdleHandler("IndicationMethodOfPeriodEndClosingDateChoiceProcessingIdleHandler", 0.1, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Identical event handlers of PeriodClosingDates and EditPeriodEndClosingDate forms.

&AtClient
Procedure PeriodEndClosingDateDetailsOnChange(Item)
	
	PeriodClosingDatesInternalClientServer.SpecifyPeriodEndClosingDateSetupOnChange(ThisObject);
	WriteCommonPeriodEndClosingDateWithDetails();
	AttachIdleHandler("UpdatePeriodEndClosingDateDisplayOnChangeIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure PeriodEndClosingDateDetailsClear(Item, StandardProcessing)
	
	StandardProcessing = False;
	PeriodEndClosingDateDetails = Items.PeriodEndClosingDateDetails.ChoiceList[0].Value;
	PeriodClosingDatesInternalClientServer.SpecifyPeriodEndClosingDateSetupOnChange(ThisObject);
	WriteCommonPeriodEndClosingDateWithDetails();
	AttachIdleHandler("UpdatePeriodEndClosingDateDisplayOnChangeIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure PeriodEndClosingDateOnChange(Item)
	
	PeriodClosingDatesInternalClientServer.SpecifyPeriodEndClosingDateSetupOnChange(ThisObject);
	WriteCommonPeriodEndClosingDateWithDetails();
	AttachIdleHandler("UpdatePeriodEndClosingDateDisplayOnChangeIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure EnableDataChangeBeforePeriodEndClosingDateOnChange(Item)
	
	PeriodClosingDatesInternalClientServer.SpecifyPeriodEndClosingDateSetupOnChange(ThisObject);
	WriteCommonPeriodEndClosingDateWithDetails();
	AttachIdleHandler("UpdatePeriodEndClosingDateDisplayOnChangeIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure PermissionDaysCountOnChange(Item)
	
	PeriodClosingDatesInternalClientServer.SpecifyPeriodEndClosingDateSetupOnChange(ThisObject);
	WriteCommonPeriodEndClosingDateWithDetails();
	AttachIdleHandler("UpdatePeriodEndClosingDateDisplayOnChangeIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure PermissionDaysCountAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting)
	
	If IsBlankString(Text) Then
		Return;
	EndIf;
	
	PermissionDaysCount = Text;
	
	PeriodClosingDatesInternalClientServer.SpecifyPeriodEndClosingDateSetupOnChange(ThisObject);
	WriteCommonPeriodEndClosingDateWithDetails();
	AttachIdleHandler("UpdatePeriodEndClosingDateDisplayOnChangeIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure MoreOptionsClick(Item)
	
	ExtendedModeSelected = True;
	Items.ExtendedMode.Visible = True;
	Items.OperationModesGroup.CurrentPage = Items.ExtendedMode;
	
EndProcedure

&AtClient
Procedure LessOptionsClick(Item)
	
	ExtendedModeSelected = False;
	Items.ExtendedMode.Visible = False;
	Items.OperationModesGroup.CurrentPage = Items.SimpleMode;
	
EndProcedure

#EndRegion

#Region UsersFormTableItemsEventHandlers

&AtClient
Procedure UsersSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	AttachIdleHandler("UsersChangeRow", 0.1, True);
	
EndProcedure

&AtClient
Procedure UsersOnActivateRow(Item)
	
	AttachIdleHandler("UpdateUserDataIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure UsersRestoreCurrentRowAfterCancelOnActivateRow()
	
	Items.Users.CurrentRow = UsersCurrentRow;
	
EndProcedure

&AtClient
Procedure UsersBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	// Do not copy as users cannot be repeated.
	If Clone Then
		Cancel = True;
		Return;
	EndIf;
	
	If UsersContinueAdding <> True Then
		Cancel = True;
		UsersContinueAdding = True;
		Items.Users.AddRow();
		Return;
	EndIf;
	
	UsersContinueAdding = Undefined;
	
	ClosingDates.GetItems().Clear();
	
EndProcedure

&AtClient
Procedure UsersBeforeRowChange(Item, Cancel)
	
	CurrentData = Item.CurrentData;
	Field          = Item.CurrentItem;
	
	If CurrentData.User = ValueForAllUsers Then
		Cancel = True;
	ElsIf Field <> Items.UsersFullPresentation
	        AND Not ValueIsFilled(CurrentData.Presentation) Then
		// All values other than a predefined value "<For all users>" are to be filled in before setting 
		// details or a period-end closing date.
		Item.CurrentItem = Items.UsersFullPresentation;
	EndIf;
	
	If Cancel Then
		Items.UsersFullPresentation.ReadOnly = False;
		Items.UsersComment.ReadOnly = False;
	Else
		Items.UsersComment.ReadOnly =
			Not ValueIsFilled(CurrentData.Presentation);
		
		If ValueIsFilled(CurrentData.Presentation) Then
			DataDetails = New Structure("PeriodEndClosingDate, PeriodEndClosingDateDetails, Comment");
			FillPropertyValues(DataDetails, CurrentData);
			
			LockUserRecordSetAtServer(CurrentData.User,
				LocksAddress, DataDetails);
			
			FillPropertyValues(CurrentData, DataDetails);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersBeforeDelete(Item, Cancel)
	
	Cancel = True;
	
	CurrentData = Items.Users.CurrentData;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("CurrentData", CurrentData);
	
	// Item for all users is always present.
	AdditionalParameters.Insert("ClosingDatesForAllUsers",
		CurrentData.User = ValueForAllUsers);
	
	If ValueIsFilled(CurrentData.Presentation)
	   AND Not CurrentData.NoPeriodEndClosingDate Then
		// Confirm to delete users with records.
		If AdditionalParameters.ClosingDatesForAllUsers Then
			QuestionText = NStr("ru = 'Отключить даты запрета для всех пользователей?'; en = 'Do you want to disable period-end closing dates for all users?'; pl = 'Chcesz odłączyć daty zakazu dla wszystkich użytkowników?';es_ES = '¿Desactivar las fechas de restricción para todos los usuarios?';es_CO = '¿Desactivar las fechas de restricción para todos los usuarios?';tr = 'Dönem sonu kapanış tarihleri tüm kullanıcılar için devre dışı bırakılsın mı?';it = 'Disattivare le date di chiusura di fine periodo per tutti gli utenti?';de = 'Verbotsdaten für alle Benutzer deaktivieren?'");
		Else
			If TypeOf(CurrentData.User) = Type("CatalogRef.Users") Then
				QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Отключить даты запрета для ""%1""?'; en = 'Do you want to disable period-end closing dates for ""%1""?'; pl = 'Chcesz odłączyć daty zakazu dla ""%1""?';es_ES = '¿Desactivar las fechas de restricción para ""%1""?';es_CO = '¿Desactivar las fechas de restricción para ""%1""?';tr = '""%1"" için dönem sonu kapanış tarihleri devre dışı bırakılsın mı?';it = 'Disattivare le date di chiusura di fine periodo per ""%1""?';de = 'Verbotsdaten für ""%1"" deaktivieren?'"), CurrentData.User);
				
			ElsIf TypeOf(CurrentData.User) = Type("CatalogRef.UserGroups") Then
				QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Отключить даты запрета для группы пользователей ""%1""?'; en = 'Do you want to disable period-end closing dates for ""%1"" user group?'; pl = 'Chcesz odłączyć daty zakazu dla grupy użytkowników ""%1""?';es_ES = '¿Desactivar las fechas de restricción para el grupo de usuarios ""%1""?';es_CO = '¿Desactivar las fechas de restricción para el grupo de usuarios ""%1""?';tr = '""%1"" kullanıcı grubu için dönem sonu kapanış tarihleri devre dışı bırakılsın mı?';it = 'Disattivare le date di chiusura di fine periodo per il gruppo utenti ""%1""?';de = 'Verbotsdaten für Benutzergruppen deaktivieren ""%1""?'"), CurrentData.User);
				
			ElsIf TypeOf(CurrentData.User) = Type("CatalogRef.ExternalUsers") Then
				QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Отключить даты запрета для внешнего пользователя ""%1""?'; en = 'Do you want to disable period-end closing dates for external user ""%1""?'; pl = 'Chcesz odłączyć daty zakazu dla zewnętrznego użytkownika ""%1""?';es_ES = '¿Desactivar las fechas de restricción para el usuario externo ""%1""?';es_CO = '¿Desactivar las fechas de restricción para el usuario externo ""%1""?';tr = '""%1"" harici kullanıcısı için dönem sonu kapanış tarihleri devre dışı bırakılsın mı?';it = 'Disabilitare le date di divieto per l''utente esterno ""%1""?';de = 'Verbotsdaten für externe Benutzer deaktivieren ""%1""?'"), CurrentData.User);
				
			ElsIf TypeOf(CurrentData.User) = Type("CatalogRef.ExternalUsersGroups") Then
				QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Отключить даты запрета для группы внешних пользователей ""%1""?'; en = 'Do you want to disable period-end closing dates for external user group ""%1""?'; pl = 'Chcesz odłączyć daty zakazu dla grupy zewnętrznych użytkowników ""%1""?';es_ES = '¿Desactivar las fechas de restricción para el grupo de los usuarios externos ""%1""?';es_CO = '¿Desactivar las fechas de restricción para el grupo de los usuarios externos ""%1""?';tr = '""%1"" harici kullanıcı grubu için dönem sonu kapanış tarihleri devre dışı bırakılsın mı?';it = 'Disattivare le date di chiusura di fine periodo per il gruppo utenti esterni ""%1""?';de = 'Verbotsdaten für externe Benutzergruppen deaktivieren ""%1""?'"), CurrentData.User);
			Else
				QuestionText = NStr("ru = 'Отключить даты запрета?'; en = 'Do you want to disable period-end closing dates?'; pl = 'Chcesz odłączyć daty zakazu?';es_ES = '¿Desactivar las fechas de restricción?';es_CO = '¿Desactivar las fechas de restricción?';tr = 'Dönem sonu kapanış tarihleri devre dışı bırakılsın mı?';it = 'Disattivare le date di chiusura di fine periodo?';de = 'Die Verbotsdaten deaktivieren?'")
			EndIf;
		EndIf;
		
		ShowQueryBox(
			New NotifyDescription(
				"UsersBeforeDeleteConfirmation", ThisObject, AdditionalParameters),
			QuestionText, QuestionDialogMode.YesNo);
		
	Else
		UsersBeforeDeleteContinue(Undefined, AdditionalParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersOnStartEdit(Item, NewRow, Clone)
	
	CurrentData = Items.Users.CurrentData;
	
	If Not ValueIsFilled(CurrentData.Presentation) Then
		CurrentData.PictureNumber = -1;
		AttachIdleHandler("UsersOnStartEditIdleHandler", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersOnEditEnd(Item, NewRow, CancelEdit)
	
	SelectedUser = Undefined;
	
	UnlockAllRecordsAtServer(LocksAddress);
	
	Items.UsersFullPresentation.ReadOnly = False;
	Items.UsersComment.ReadOnly = False;
	
EndProcedure

&AtClient
Procedure UsersChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	UsersChoiceProcessingAtServer(ValueSelected);
	
EndProcedure

&AtServer
Procedure UsersChoiceProcessingAtServer(SelectedValue)
	
	Filter = New Structure("User");
	
	For Each Value In SelectedValue Do
		Filter.User = Value;
		If ClosingDatesUsers.FindRows(Filter).Count() = 0 Then
			LockAndWriteBlankDates(LocksAddress,
				SectionEmptyRef, SectionEmptyRef, Filter.User, "");
			
			UserDetails = ClosingDatesUsers.Add();
			UserDetails.User  = Filter.User;
			
			UserDetails.Presentation = UserPresentationText(
				ThisObject, Filter.User);
			
			UserDetails.FullPresentation = UserDetails.Presentation;
		EndIf;
	EndDo;
	
	FillPicturesNumbersOfClosingDatesUsers(ThisObject);
	
	UnlockAllRecordsAtServer(LocksAddress);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the FullPresentation item of the Users form table.

&AtClient
Procedure UsersFullPresentationOnChange(Item)
	
	CurrentData = Items.Users.CurrentData;
	
	If Not ValueIsFilled(CurrentData.FullPresentation) Then
		CurrentData.FullPresentation = CurrentData.Presentation;
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersFullPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.Users.CurrentData;
	If CurrentData.User = ValueForAllUsers Then
		Return;
	EndIf;
	
	// Users can be replaced with themselves or with users not selected in the list.
	SelectPickUsers();
	
EndProcedure

&AtClient
Procedure UsersFullPresentationClear(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure UsersFullPresentationOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	If ValueIsFilled(Items.Users.CurrentData.User) Then
		ShowValue(, Items.Users.CurrentData.User);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersFullPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.Users.CurrentData;
	If CurrentData.User = ValueSelected Then
		CurrentData.FullPresentation = CurrentData.Presentation;
		Return;
	EndIf;
	
	SelectedUser = ValueSelected;
	AttachIdleHandler("UsersFullPresentationChoiceProcessingIdleHandler", 0.1, True);
	
EndProcedure

&AtClient
Procedure UsersFullPresentationAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting)
	
	If ValueIsFilled(Text) Then
		Waiting = False;
		ChoiceData = GenerateUserSelectionData(Text);
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersFullPresentationTextEditEnd(Item, Text, ChoiceData, DataGetParameters)
	
	If ValueIsFilled(Text) Then
		DataGetParameters = False;
		ChoiceData = GenerateUserSelectionData(Text);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the Comment item of the Users form table.

&AtClient
Procedure UsersCommentOnChange(Item)
	
	CurrentData = Items.Users.CurrentData;
	
	WriteComment(CurrentData.User, CurrentData.Comment);
	NotifyChanged(Type("InformationRegisterRecordKey.PeriodClosingDates"));
	
EndProcedure

#EndRegion

#Region ItemsEventHandlersOfPeriodEndClosingDateFormTable

&AtClient
Procedure ClosingDatesChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	AttachIdleHandler("ClosingDatesChangeRow", 0.1, True);
	
EndProcedure

&AtClient
Procedure ClosingDatesOnActivateRow(Item)
	
	ClosingDatesSetCommandsAvailability(Items.ClosingDates.CurrentData <> Undefined);
	
EndProcedure

&AtClient
Procedure ClosingDatesBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	If Not Items.ClosingDatesAdd.Enabled Then
		Cancel = True;
		Return;
	EndIf;
	
	If Clone
	 Or AllSectionsWithoutObjects
	 Or PeriodEndClosingDateSettingMethod = "BySections" Then
		
		Cancel = True;
		Return;
	EndIf;
	
	If CurrentUser = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	CurrentSection = CurrentSection(, True);
	If CurrentSection = SectionEmptyRef Then
		ShowMessageBox(, MessageTextInSelectedSectionClosingDatesForObjectsNotSet(CurrentSection));
		Cancel = True;
		Return;
	EndIf;
	
	SectionObjectsTypes = Sections.Get(CurrentSection).ObjectsTypes;
	
	CurrentData = Items.ClosingDates.CurrentData;
	
	If SectionObjectsTypes <> Undefined
	   AND SectionObjectsTypes.Count() > 0 Then
		
		If ShowCurrentUserSections Then
			Parent = CurrentData.GetParent();
			
			If Not CurrentData.IsSection
			      AND Parent <> Undefined Then
				// Adding the object to the section.
				Cancel = True;
				Item.CurrentRow = Parent.GetID();
				Item.AddRow();
			EndIf;
		ElsIf Item.CurrentRow <> Undefined Then
			Cancel = True;
			Item.CurrentRow = Undefined;
			Item.AddRow();
		EndIf;
	Else
		ShowMessageBox(, MessageTextInSelectedSectionClosingDatesForObjectsNotSet(CurrentSection));
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ClosingDatesBeforeRowChange(Item, Cancel)
	
	If Not Items.ClosingDatesChange.Enabled Then
		Cancel = True;
		Return;
	EndIf;
	
	CurrentData = Item.CurrentData;
	Field = Items.ClosingDates.CurrentItem;
	
	// Going to an available field or opening a form.
	OpenPeriodEndClosingDateEditForm = False;
	
	If Field = Items.ClosingDatesFullPresentation Then
		If CurrentData.IsSection Then
			If IsAllUsers(CurrentUser) Then
				// All sections are always filled in, do not change them.
				If CurrentData.PeriodEndClosingDateDetails <> "CustomDate"
				 Or Field = Items.ClosingDatesDetailsClosingDatesPresentation Then
					OpenPeriodEndClosingDateEditForm = True;
				Else
					CurrentItem = Items.ClosingDatesClosingDate;
				EndIf;
			EndIf;
			
		ElsIf ValueIsFilled(CurrentData.Presentation) Then
			If CurrentData.PeriodEndClosingDateDetails <> "CustomDate"
			 Or Field = Items.ClosingDatesDetailsClosingDatesPresentation Then
				OpenPeriodEndClosingDateEditForm = True;
			Else
				CurrentItem = Items.ClosingDatesClosingDate;
			EndIf;
		EndIf;
	Else
		If Not ValueIsFilled(CurrentData.Presentation) Then
			// Fill in the object before changing description or a period-end closing date, otherwise, data 
			// cannot be written to the register.
			CurrentItem = Items.ClosingDatesFullPresentation;
			
		ElsIf CurrentData.PeriodEndClosingDateDetails <> "CustomDate"
			  Or Field = Items.ClosingDatesDetailsClosingDatesPresentation Then
			OpenPeriodEndClosingDateEditForm = True;
			
		ElsIf CurrentItem = Items.ClosingDatesClosingDate Then
			CurrentItem = Items.ClosingDatesClosingDate;
		EndIf;
	EndIf;
	
	// Locking the record before editing.
	If ValueIsFilled(CurrentData.Presentation) Then
		ReadProperties = LockUserRecordAtServer(LocksAddress,
			CurrentSection(), CurrentData.Object, CurrentUser);
		
		UpdateReadPropertiesValues(
			CurrentData, ReadProperties, Items.Users.CurrentData);
	EndIf;
	
	If OpenPeriodEndClosingDateEditForm Then
		Cancel = True;
		EditPeriodEndClosingDateInForm();
	EndIf;
	
	If Cancel Then
		Items.ClosingDatesFullPresentation.ReadOnly = False;
		Items.ClosingDatesDetailsClosingDatesPresentation.ReadOnly = False;
		Items.ClosingDatesClosingDate.ReadOnly = False;
	Else
		// Locking unavailable fields.
		Items.ClosingDatesFullPresentation.ReadOnly =
			ValueIsFilled(CurrentData.Presentation);
		
		Items.ClosingDatesDetailsClosingDatesPresentation.ReadOnly = True;
		Items.ClosingDatesClosingDate.ReadOnly =
			    Not ValueIsFilled(CurrentData.Presentation)
			Or CurrentData.PeriodEndClosingDateDetails <> "CustomDate";
	EndIf;
	
EndProcedure

&AtClient
Procedure ClosingDatesBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	CurrentData = Items.ClosingDates.CurrentData;
	
	If CurrentData.IsSection Then
		If ValueIsFilled(CurrentData.Section) Then
			If CurrentData.GetItems().Count() > 0 Then
				QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Отключить все настроенные даты запрета для раздела ""%1"" и его объектов?'; en = 'Do you want to disable all set period-end closing dates for the ""%1"" section and its objects?'; pl = 'Chcesz odłączyć wszystkie skonfigurowane daty zakazu dla sekcji ""%1"" i jej obiektów?';es_ES = '¿Desactivar todas las fechas de restricción ajustadas para la sección ""%1"" y sus objetos?';es_CO = '¿Desactivar todas las fechas de restricción ajustadas para la sección ""%1"" y sus objetos?';tr = '""%1"" bölümü ve nesneleri için belirlenen tüm dönem sonu kapanış tarihleri devre dışı bırakılsın mı?';it = 'Disattivare tutte le date di chiusura di fine periodo impostate per le sezioni ""%1"" e i suoi oggetti?';de = 'Alle konfigurierten Verbotsdaten für den Abschnitt ""%1"" und seine Objekte deaktivieren?'"), CurrentData.Section);
			Else
				QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Отключить дату запрета для раздела ""%1""?'; en = 'Do you want to disable a period-end closing date for the ""%1"" section?'; pl = 'Chcesz odłączyć datę zakazu dla sekcji ""%1""?';es_ES = '¿Desactivar la fecha de restricción para la sección ""%1""?';es_CO = '¿Desactivar la fecha de restricción para la sección ""%1""?';tr = '""%1"" bölümü için dönem sonu kapanış tarihi devre dışı bırakılsın mı?';it = 'Disattivare la data di chiusura di fine periodo per la sezione ""%1""?';de = 'Das Verbotsdatum für den Abschnitt ""%1"" deaktivieren?'"), CurrentData.Section);
			EndIf;
		Else
			QuestionText = NStr("ru = 'Отключить общую дату запрета для всех разделов?'; en = 'Do you want to disable a common period-end closing date set for all sections?'; pl = 'Chcesz odłączyć całkowitą datę zakazu dla wszystkich sekcji?';es_ES = '¿Desactivar la fecha de restricción común para todas las secciones?';es_CO = '¿Desactivar la fecha de restricción común para todas las secciones?';tr = 'Tüm bölümler için belirlenen ortak dönem sonu kapanış tarihleri devre dışı bırakılsın mı?';it = 'Disattivare la data di chiusura generale di fine periodo impostata per tutte le sezioni?';de = 'Das gesamte Verbotsdatum für alle Abschnitte deaktivieren?'");
		EndIf;
	Else
		QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Отключить дату запрета для объекта ""%1""?'; en = 'Do you want to disable a period-end closing date for the ""%1"" object?'; pl = 'Chcesz odłączyć datę zakazu na obiekcie ""%1""?';es_ES = '¿Desactivar la fecha de restricción del objeto ""%1""?';es_CO = '¿Desactivar la fecha de restricción del objeto ""%1""?';tr = '""%1"" nesnesi için dönem sonu kapanış tarihi devre dışı bırakılsın mı?';it = 'Disattivare la data di chiusura di fine periodo per l''oggetto ""%1""?';de = 'Verbotsdatum für Objekt ""%1"" deaktivieren?'"), CurrentData.Object);
	EndIf;
	
	Delete = True;
	
	If CurrentData.IsSection Then
		Delete = False;
		SectionItems = CurrentData.GetItems();
		
		If PeriodEndClosingDateSet(CurrentData, CurrentUser)
		 Or SectionItems.Count() > 0 Then
			// Deleting a period-end closing date for the section (i.e. all section objects).
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("CurrentData", CurrentData);
			AdditionalParameters.Insert("SectionItems", SectionItems);
			AdditionalParameters.Insert("Delete", Delete);
			
			ShowQueryBox(
				New NotifyDescription(
					"ClosingDatesBeforeDeleteSectionFollowUp", ThisObject, AdditionalParameters),
				QuestionText, QuestionDialogMode.YesNo);
		Else
			MessageText = NStr("ru = 'Для отключения даты запрета по конкретному объекту необходимо выбрать интересующий объект в одном из разделов.'; en = 'To disable a period-end closing date of a specific object, select the required object in one of the sections.'; pl = 'Aby wyłączyć datę zakazu dla danego obiektu, musisz wybrać obiekt, będący przedmiotem zainteresowania, w jednej z sekcji.';es_ES = 'Para desactivar la fecha de restricción por el objeto concreto es necesario seleccionar este objeto en una de las secciones.';es_CO = 'Para desactivar la fecha de restricción por el objeto concreto es necesario seleccionar este objeto en una de las secciones.';tr = 'Belirli bir nesnenin dönem sonu kapanış tarihini devre dışı bırakmak için, bölümlerden birinde ilgili nesneyi seçin.';it = 'Per disattivare la data di chiusura di fine periodo di uno specifico oggetto, selezionare l''oggetto richiesto in una delle sezioni.';de = 'Um das Verbotsdatum für ein bestimmtes Objekt zu deaktivieren, sollten Sie das Objekt von Interesse in einem der Abschnitte auswählen.'");
			ShowMessageBox(, MessageText);
		EndIf;
		Return;
	EndIf;
		
	If PeriodEndClosingDateSet(CurrentData, CurrentUser) Then
		// Deleting a period-end closing date for the object by section.
		ShowQueryBox(
			New NotifyDescription(
				"ClosingDatesBeforeDeleteObjectFollowUp", ThisObject, CurrentData),
			QuestionText, QuestionDialogMode.YesNo);
		Return;
	EndIf;
	
	If Delete Then
		ClosingDatesOnDelete(CurrentData);
	EndIf;
	
EndProcedure

&AtClient
Procedure ClosingDatesOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		If Not Items.ClosingDates.CurrentData.IsSection Then
			Items.ClosingDates.CurrentData.Section = CurrentSection(, True);
		EndIf;
		If IsAllUsers(CurrentUser)
		 Or Not Items.ClosingDates.CurrentData.IsSection Then
			Items.ClosingDates.CurrentData.PeriodEndClosingDateDetails = "CustomDate";
		EndIf;
		Items.ClosingDates.CurrentData.PeriodEndClosingDateDetailsPresentation =
			DetailsPresentationOfPeriodEndClosingDate(Items.ClosingDates.CurrentData);
		
		AttachIdleHandler("IdleHandlerSelectObjects", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ClosingDatesOnEditEnd(Item, NewRow, CancelEdit)
	
	CurrentData = Items.ClosingDates.CurrentData;
	
	If CurrentUser <> Undefined Then
		WriteDetailsAndPeriodEndClosingDate(CurrentData);
	EndIf;
	
	UnlockAllRecordsAtServer(LocksAddress);
	
	Items.ClosingDatesFullPresentation.ReadOnly = False;
	Items.ClosingDatesDetailsClosingDatesPresentation.ReadOnly = False;
	Items.ClosingDatesDetailsClosingDatesPresentation.ReadOnly = False;
	
	UpdateClosingDatesAvailabilityOfCurrentUser();
	
EndProcedure

&AtClient
Procedure ClosingDatesChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.ClosingDates.CurrentData;
	
	If CurrentData <> Undefined
	   AND CurrentData.Object = ValueSelected Then
		
		Return;
	EndIf;
	
	SectionID = Undefined;
	
	If ShowCurrentUserSections Then
		Parent = CurrentData.GetParent();
		If Parent = Undefined Then
			ObjectCollection    = CurrentData.GetItems();
			SectionID = CurrentData.GetID();
		Else
			ObjectCollection    = Parent.GetItems();
			SectionID = Parent.GetID();
		EndIf;
	Else
		ObjectCollection = ClosingDates.GetItems();
	EndIf;
	
	If TypeOf(ValueSelected) = Type("Array") Then
		Objects = ValueSelected;
	Else
		Objects = New Array;
		Objects.Add(ValueSelected);
	EndIf;
	
	ObjectsForAdding = New Array;
	For Each Object In Objects Do
		ValueNotFound = True;
		For Each Row In ObjectCollection Do
			If Row.Object = Object Then
				ValueNotFound = False;
				Break;
			EndIf;
		EndDo;
		If ValueNotFound Then
			ObjectsForAdding.Add(Object);
		EndIf;
	EndDo;
	
	If ObjectsForAdding.Count() > 0 Then
		WriteDates = CurrentUser <> Undefined;
		
		If WriteDates Then
			Comment = CurrentUserComment(ThisObject);
			
			LockAndWriteBlankDates(LocksAddress,
				CurrentSection(, True), ObjectsForAdding, CurrentUser, Comment);
			
			NotifyChanged(Type("InformationRegisterRecordKey.PeriodClosingDates"));
		EndIf;
		
		For Each CurrentObject In ObjectsForAdding Do
			ObjectDetails = ObjectCollection.Add();
			ObjectDetails.Section        = CurrentSection(, True);
			ObjectDetails.Object        = CurrentObject;
			ObjectDetails.Presentation = String(CurrentObject);
			ObjectDetails.FullPresentation = ObjectDetails.Presentation;
			ObjectDetails.PeriodEndClosingDateDetails = "CustomDate";
			
			ObjectDetails.PeriodEndClosingDateDetailsPresentation =
				DetailsPresentationOfPeriodEndClosingDate(ObjectDetails);
			
			ObjectDetails.RecordExists = WriteDates;
		EndDo;
		
		If SectionID <> Undefined Then
			Items.ClosingDates.Expand(SectionID, True);
		EndIf;
	EndIf;
	
	UpdateClosingDatesAvailabilityOfCurrentUser();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the FullPresentation item of the ClosingDates form table.

&AtClient
Procedure ClosingDatesFullPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	SelectPickObjects();
	
EndProcedure

&AtClient
Procedure ClosingDatesFullPresentationClear(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure ClosingDatesFullPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.ClosingDates.CurrentData;
	
	If CurrentData.Object = ValueSelected Then
		Return;
	EndIf;
	
	// Object can be replaced only with another object, which is not in the list.
	If ShowCurrentUserSections Then
		ObjectCollection = CurrentData.GetParent().GetItems();
	Else
		ObjectCollection = ClosingDates.GetItems();
	EndIf;
	
	ValueFound = True;
	For Each Row In ObjectCollection Do
		If Row.Object = ValueSelected Then
			ValueFound = False;
			Break;
		EndIf;
	EndDo;
	
	If Not ValueFound Then
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '""%1"" уже есть в списке объектов'; en = '""%1"" is already in the object list'; pl = '""%1"" już jest na liście objektów.';es_ES = '""%1"" ya existe en la lista de objetos';es_CO = '""%1"" ya existe en la lista de objetos';tr = '""%1"" nesne listesinde zaten mevcut';it = '""%1"" è già nell''elenco oggetti';de = '""%1"" ist bereits auf der Liste der Objekte'"), ValueSelected));
		Return;
	EndIf;
	
	If CurrentData.Object <> ValueSelected Then
		
		PropertiesValues = GetCurrentPropertiesValues(
			CurrentData, Items.Users.CurrentData);
		
		If Not ReplaceObjectInUserRecordAtServer(
					CurrentData.Section,
					CurrentData.Object,
					ValueSelected,
					CurrentUser,
					PropertiesValues,
					LocksAddress) Then
			
			ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '""%1"" уже есть в списке объектов.
					|Обновите данные формы (клавиша F5).'; 
					|en = '""%1"" is already in the object list.
					|Refresh the form (F5).'; 
					|pl = '""%1"" już znajduje się na liście obiektów. 
					|Zaktualizuj dane formularza (klawisz F5).';
					|es_ES = '""%1"" ya existe en la lista de objetos.
					|Actualice los datos del formulario (tecla F5).';
					|es_CO = '""%1"" ya existe en la lista de objetos.
					|Actualice los datos del formulario (tecla F5).';
					|tr = '""%1"" nesne listesinde zaten mevcut.
					|Formu yenileyin (F5).';
					|it = '""%1"" è già nell''elenco degli oggetti.
					| Aggiornare i dati del modulo (tasto F5).';
					|de = '""%1"" ist bereits auf der Liste der Objekte.
					|Aktualisieren Sie die Formulardaten (Taste F5).'"), ValueSelected));
			Return;
		Else
			UpdateReadPropertiesValues(
				CurrentData, PropertiesValues, Items.Users.CurrentData);
			
			NotifyChanged(Type("InformationRegisterRecordKey.PeriodClosingDates"));
		EndIf;
	EndIf;
	
	// Setting the selected object.
	CurrentData.Object = ValueSelected;
	CurrentData.Presentation = String(CurrentData.Object);
	CurrentData.FullPresentation = CurrentData.Presentation;
	Items.ClosingDates.EndEditRow(False);
	Items.ClosingDates.CurrentItem = Items.ClosingDatesClosingDate;
	AttachIdleHandler("ClosingDatesChangeRow", 0.1, True);
	
	UpdateClosingDatesAvailabilityOfCurrentUser();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the PeriodEndClosingDate item of the ClosingDates form table.

&AtClient
Procedure ClosingDatesPeriodEndClosingDateOnChange(Item)
	
	WriteDetailsAndPeriodEndClosingDate();
	
	UpdateClosingDatesAvailabilityOfCurrentUser();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Update(Command)
	
	UpdateAtServer();
	ExpandUserData();
	
EndProcedure

&AtClient
Procedure PickObjects(Command)
	
	If CurrentUser = Undefined Then
		Return;
	EndIf;
	
	SelectPickObjects(True);
	
EndProcedure

&AtClient
Procedure PickUsers(Command)
	
	SelectPickUsers(True);
	
EndProcedure

&AtClient
Procedure ShowReport(Command)
	
	If Parameters.DataImportRestrictionDates Then
		ReportFormName = "Report.ImportRestrictionDates.Form";
	Else
		ReportFormName = "Report.PeriodClosingDates.Form";
	EndIf;
	
	OpenForm(ReportFormName);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// Marking a required user.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.UsersFullPresentation.Name);
	Item.Appearance.SetParameterValue("MarkIncomplete", True);
	
	FIlterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FIlterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDatesUsers.FullPresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	FIlterGroup2 = FIlterGroup1.Items.Add(Type("DataCompositionFilterItemGroup"));
	FIlterGroup2.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	
	ItemFilter = FIlterGroup2.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDatesUsers.User");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotInList;
	ValueList = New ValueList;
	ValueList.Add(Enums.PeriodClosingDatesPurposeTypes.ForAllUsers);
	ValueList.Add(Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases);
	ItemFilter.RightValue = ValueList;
	
	ItemFilter = FIlterGroup2.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDatesUsers.NoPeriodEndClosingDate");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	// Marking a required object.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ClosingDatesFullPresentation.Name);
	Item.Appearance.SetParameterValue("MarkIncomplete", True);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDates.FullPresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	// Registering a blank date.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ClosingDatesClosingDate.Name);
	Item.Appearance.SetParameterValue("Format",
		StringFunctionsClientServer.SubstituteParametersToString("DE='%1'", NStr("ru = 'Без запрета'; en = 'Without period-end closing'; pl = 'Bez zakazu';es_ES = 'Sin restricción';es_CO = 'Sin restricción';tr = 'Dönem sonu kapanışı olmadan';it = 'Senza chiusure di fine periodo';de = 'Ohne Verbot'")));
	
	FIlterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FIlterGroup1.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	
	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDates.RecordExists");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ClosingDates.PeriodEndClosingDate");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = '00010101';
	
EndProcedure

&AtClient
Procedure ClosingDatesChangeRow()
	
	Items.ClosingDates.ChangeRow();
	
EndProcedure

&AtClient
Procedure UsersChangeRow()
	
	Items.Users.ChangeRow();
	
EndProcedure

&AtClient
Procedure SetPeriodEndClosingDateChoiceProcessingContinue(Response, SelectedValue) Export
	
	If Response = DialogReturnCode.No Then
		SetPeriodEndClosingDateNew = SetPeriodEndClosingDate; 
		Return;
	EndIf;
	
	SetPeriodEndClosingDate = SelectedValue;
	ChangeSettingOfPeriodEndClosingDate(SelectedValue, True);
	
EndProcedure

&AtClient
Procedure IndicationMethodOfPeriodEndClosingDateChoiceProcessingIdleHandler()
	
	SelectedValue = SelectedMethodOfPeriodEndClosingDateIndication;
	
	Data = Undefined;
	CurrentMethod = CurrentIndicationMethodOfPeriodEndClosingDate(CurrentUser,
		SingleSection, ValueForAllUsers, BegOfDay, Data);
	
	QuestionText = "";
	If CurrentMethod = "BySectionsAndObjects" AND SelectedValue = "SingleDate" Then
		QuestionText = NStr("ru = 'Отключить даты запрета, установленные для разделов и объектов?'; en = 'Do you want to disable period-end closing dates set for sections and objects?'; pl = 'Chcesz odłączyć daty zakazów ustawione dla sekcji i obiektów?';es_ES = '¿Desactivar las fechas de restricción para secciones y objetos?';es_CO = '¿Desactivar las fechas de restricción para secciones y objetos?';tr = 'Bölümler ve nesneler için belirlenen dönem sonu kapanış tarihleri devre dışı bırakılsın mı?';it = 'Disattivare le date di chiusura di fine periodo impostate per le sezioni e gli oggetti?';de = 'Verbotsdaten für Partitionen und Objekte deaktivieren?'");
		
	ElsIf CurrentMethod = "BySectionsAndObjects" AND SelectedValue = "BySections"
	      Or CurrentMethod = "ByObjects"          AND SelectedValue = "SingleDate" Then
		QuestionText = NStr("ru = 'Отключить даты запрета, установленные для объектов?'; en = 'Do you want to disable period-end closing dates set for objects?'; pl = 'Chcesz odłączyć daty zakazów ustawione dla obiektów?';es_ES = '¿Desactivar las fechas de restricción para objetos?';es_CO = '¿Desactivar las fechas de restricción para objetos?';tr = 'Nesneler için belirlenen dönem sonu kapanış tarihleri devre dışı bırakılsın mı?';it = 'Disattivare le date di chiusura di fine periodo impostate per gli oggetti?';de = 'Verbotsdaten für Objekte deaktivieren?'");
		
	ElsIf CurrentMethod = "BySectionsAndObjects" AND SelectedValue = "ByObjects"
	      Or CurrentMethod = "BySections"          AND SelectedValue = "ByObjects"
	      Or CurrentMethod = "BySections"          AND SelectedValue = "SingleDate" Then
		QuestionText = NStr("ru = 'Отключить даты запрета, установленные для разделов?'; en = 'Do you want to disable period-end closing dates set for sections?'; pl = 'Chcesz odłączyć daty zakazów ustawione dla sekcji?';es_ES = '¿Desactivar las fechas de restricción para secciones?';es_CO = '¿Desactivar las fechas de restricción para secciones?';tr = 'Bölümler için belirlenen dönem sonu kapanış tarihleri devre dışı bırakılsın mı?';it = 'Disattivare le date di chiusura di fine periodo impostate per le sezioni?';de = 'Verbotsdaten für Abschnitte deaktivieren?'");
		
	EndIf;
	
	If ValueIsFilled(QuestionText) Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Data", Data);
		AdditionalParameters.Insert("SelectedValue", SelectedValue);
		
		ShowQueryBox(
			New NotifyDescription(
				"IndicationMethodOfPeriodEndClosingDateChoiceProcessingContinue",
				ThisObject,
				AdditionalParameters),
			QuestionText,
			QuestionDialogMode.YesNo);
	Else
		PeriodEndClosingDateSettingMethod = SelectedValue;
		ReadUserData(ThisObject, SelectedValue, Data);
	EndIf;
	
EndProcedure

&AtClient
Procedure IndicationMethodOfPeriodEndClosingDateChoiceProcessingContinue(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	PeriodEndClosingDateSettingMethod = AdditionalParameters.SelectedValue;
	
	DeleteExtraOnChangePeriodEndClosingDateIndicationMethod(
		AdditionalParameters.SelectedValue,
		CurrentUser,
		SetPeriodEndClosingDate);
	
	Items.Users.Refresh();
	
	ReadUserData(ThisObject,
		AdditionalParameters.SelectedValue,
		AdditionalParameters.Data);
	
EndProcedure

&AtClient
Procedure UsersFullPresentationChoiceProcessingIdleHandler()
	
	CurrentData = Items.Users.CurrentData;
	If CurrentData = Undefined Or SelectedUser = Undefined Then
		Return;
	EndIf;
	SelectedValue = SelectedUser;
	
	// You can replace the user only with another user that is not in the list.
	// 
	Filter = New Structure("User", SelectedValue);
	Rows = ClosingDatesUsers.FindRows(Filter);
	
	If Rows.Count() = 0 Then
		If Not ReplaceUserRecordSet(CurrentUser, SelectedValue, LocksAddress) Then
			ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '""%1"" уже есть в списке пользователей.
					|Обновите данные формы (клавиша F5).'; 
					|en = '""%1"" is already in the user list.
					|Refresh the form (F5).'; 
					|pl = '""%1"" już znajduje się na liście użytkowników. 
					|Zaktualizuj dane formularza (klawisz F5).';
					|es_ES = '""%1"" ya existe en la lista de usuarios.
					|Actualice los datos del formulario (tecla F5).';
					|es_CO = '""%1"" ya existe en la lista de usuarios.
					|Actualice los datos del formulario (tecla F5).';
					|tr = '""%1"" kullanıcı listesinde zaten mevcut.
					|Formu yenileyin (F5).';
					|it = '""%1"" è già presente nell''elenco degli utenti. 
					| Aggiornare i dati del modulo (tasto F5).';
					|de = '""%1"" ist bereits auf der Liste der Benutzer.
					|Aktualisieren Sie die Formulardaten (Taste F5).'"), SelectedValue));
			Return;
		EndIf;
		// Setting the selected user.
		CurrentUser = Undefined;
		CurrentData.User  = SelectedValue;
		CurrentData.Presentation = UserPresentationText(ThisObject, SelectedValue);
		CurrentData.FullPresentation = CurrentData.Presentation;
		
		Items.UsersComment.ReadOnly = False;
		FillPicturesNumbersOfClosingDatesUsers(ThisObject, Items.Users.CurrentRow);
		Items.Users.EndEditRow(False);
		
		UpdateUserData();
		
		NotifyChanged(Type("InformationRegisterRecordKey.PeriodClosingDates"));
		Items.Users.CurrentItem = Items.UsersComment;
		AttachIdleHandler("UsersChangeRow", 0.1, True);
	Else
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '""%1"" уже есть в списке пользователей.'; en = '""%1"" is already in the user list.'; pl = '""%1"" już jest na liście użytkowników.';es_ES = '""%1"" ya existe en la lista de usuarios.';es_CO = '""%1"" ya existe en la lista de usuarios.';tr = '""%1"" kullanıcı listesinde zaten mevcut';it = '""%1"" è già presente nell''elenco degli utenti.';de = '""%1"" ist bereits auf der Benutzerliste.'"), SelectedValue));
	EndIf;
	
EndProcedure

&AtClient
Procedure UsersBeforeDeleteConfirmation(Response, AdditionalParameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	DeleteUserRecordSet(AdditionalParameters.CurrentData.User,
		LocksAddress);
	
	If AdditionalParameters.ClosingDatesForAllUsers Then
		If PeriodEndClosingDateSettingMethod = "SingleDate" Then
			PeriodEndClosingDate         = '00010101';
			PeriodEndClosingDateDetails = "";
			RecordExists = False;
			PeriodClosingDatesInternalClientServer.SpecifyPeriodEndClosingDateSetupOnChange(ThisObject);
			PeriodClosingDatesInternalClientServer.UpdatePeriodEndClosingDateDisplayOnChange(ThisObject);
		EndIf;
		AdditionalParameters.Insert("DataDeleted");
		UpdateClosingDatesAvailabilityOfCurrentUser();
	EndIf;
	
	NotifyChanged(Type("InformationRegisterRecordKey.PeriodClosingDates"));
	
	UsersBeforeDeleteContinue(Undefined, AdditionalParameters);
	
EndProcedure

&AtClient
Procedure UsersBeforeDeleteContinue(NotDefined, AdditionalParameters)
	
	CurrentData = AdditionalParameters.CurrentData;
	
	If AdditionalParameters.ClosingDatesForAllUsers Then
		If ShowCurrentUserSections Then
			For Each SectionDetails In ClosingDates.GetItems() Do
				If PeriodEndClosingDateSet(SectionDetails, CurrentUser)
				 Or SectionDetails.GetItems().Count() > 0 Then
					SectionDetails.PeriodEndClosingDate         = '00010101';
					SectionDetails.PeriodEndClosingDateDetails = "";
					SectionDetails.GetItems().Clear();
					SectionDetails.RecordExists = False;
					SectionDetails.PeriodEndClosingDateDetailsPresentation =
						DetailsPresentationOfPeriodEndClosingDate(SectionDetails);
				EndIf;
			EndDo;
		Else
			If ClosingDates.GetItems().Count() > 0 Then
				ClosingDates.GetItems().Clear();
			EndIf;
		EndIf;
		CurrentData.NoPeriodEndClosingDate = True;
		CurrentData.FullPresentation = CurrentData.Presentation;
		Return;
	EndIf;
	
	PeriodEndClosingDateSettingMethod = Undefined;
	UsersOnDelete();
	
EndProcedure

&AtClient
Procedure UsersOnDelete()
	
	Index = ClosingDatesUsers.IndexOf(ClosingDatesUsers.FindByID(
		Items.Users.CurrentRow));
	
	ClosingDatesUsers.Delete(Index);
	
	If ClosingDatesUsers.Count() <= Index AND Index > 0 Then
		Index = Index -1;
	EndIf;
	
	If ClosingDatesUsers.Count() > 0 Then
		Items.Users.CurrentRow =
			ClosingDatesUsers[Index].GetID();
	EndIf;
	
EndProcedure

&AtClient
Procedure ClosingDatesBeforeDeleteSectionFollowUp(Response, AdditionalParameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	CurrentData   = AdditionalParameters.CurrentData;
	SectionItems = AdditionalParameters.SectionItems;
	
	SectionObjects = New Array;
	SectionObjects.Add(CurrentData.Section);
	
	For Each DataItem In SectionItems Do
		SectionObjects.Add(DataItem.Object);
	EndDo;
	
	DeleteUserRecord(LocksAddress,
		CurrentData.Section, SectionObjects, CurrentUser);
	
	SectionItems.Clear();
	CurrentData.PeriodEndClosingDate         = '00010101';
	CurrentData.PeriodEndClosingDateDetails = "";
	
	If AdditionalParameters.Delete Then
		ClosingDatesOnDelete(CurrentData);
	Else
		CurrentData.PeriodEndClosingDateDetailsPresentation =
			DetailsPresentationOfPeriodEndClosingDate(CurrentData);
	EndIf;
	
	NotifyChanged(Type("InformationRegisterRecordKey.PeriodClosingDates"));
	
EndProcedure

&AtClient
Procedure ClosingDatesBeforeDeleteObjectFollowUp(Response, CurrentData) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	DeleteUserRecord(LocksAddress,
		CurrentSection(),
		CurrentData.Object,
		CurrentUser);
	
	If CurrentSection() = CurrentData.Object Then
		// Common date is deleted.
		PeriodEndClosingDate         = '00010101';
		PeriodEndClosingDateDetails = "";
		RecordExists    = False;
	EndIf;
	
	ClosingDatesOnDelete(CurrentData);
	
	NotifyChanged(Type("InformationRegisterRecordKey.PeriodClosingDates"));
	
EndProcedure

&AtClient
Procedure ClosingDatesOnDelete(CurrentData)
	
	CurrentParent = CurrentData.GetParent();
	If CurrentParent = Undefined Then
		ClosingDatesItems = ClosingDates.GetItems();
	Else
		ClosingDatesItems = CurrentParent.GetItems();
	EndIf;
	
	Index = ClosingDatesItems.IndexOf(CurrentData);
	
	ClosingDatesItems.Delete(Index);
	
	If ClosingDatesItems.Count() <= Index AND Index > 0 Then
		Index = Index -1;
	EndIf;
	
	If ClosingDatesItems.Count() > 0 Then
		Items.ClosingDates.CurrentRow =
			ClosingDatesItems[Index].GetID();
		
	ElsIf CurrentParent <> Undefined Then
		Items.ClosingDates.CurrentRow =
			CurrentParent.GetID();
	EndIf;
	
	UpdateClosingDatesAvailabilityOfCurrentUser();
	
EndProcedure

&AtServer
Procedure UpdateAtServer()
	
	OnChangeOfRestrictionDatesUsageAtServer();
	
	// Calculating a restriction date setting.
	SetPeriodEndClosingDate = CurrentSettingOfPeriodEndClosingDate(Parameters.DataImportRestrictionDates);
	SetPeriodEndClosingDateNew = SetPeriodEndClosingDate;
	// Setting visibility according to the calculated import restriction date setting.
	SetVisibility();
	
	// Caching the current date on the server.
	BegOfDay = BegOfDay(CurrentSessionDate());
	
	OldUser = CurrentUser;
	
	ReadUsers();
	
	Filter = New Structure("User", OldUser);
	FoundRows = ClosingDatesUsers.FindRows(Filter);
	If FoundRows.Count() = 0 Then
		CurrentUser = ValueForAllUsers;
	Else
		Items.Users.CurrentRow = FoundRows[0].GetID();
		CurrentUser = OldUser;
	EndIf;
	
	ReadUserData(ThisObject);
	
EndProcedure

&AtClient
Procedure UpdateUserDataIdleHandler()
	
	UpdateUserData();
	
EndProcedure

&AtClient
Procedure UpdateUserData()
	
	CurrentData = Items.Users.CurrentData;
	
	If CurrentData = Undefined
	 Or Not ValueIsFilled(CurrentData.Presentation) Then
		
		NewUser = Undefined;
	Else
		NewUser = CurrentData.User;
	EndIf;
	
	If NewUser = CurrentUser Then
		Return;
	EndIf;
	
	IndicationMethodValueInList =
		Items.PeriodEndClosingDateSettingMethod.ChoiceList.FindByValue(PeriodEndClosingDateSettingMethod);
	
	If CurrentUser <> Undefined
	   AND IndicationMethodValueInList <> Undefined Then
		
		CurrentIndicationMethod = CurrentIndicationMethodOfPeriodEndClosingDate(
			CurrentUser, SingleSection, ValueForAllUsers, BegOfDay);
		
		CurrentIndicationMethod =
			?(ValueIsFilled(CurrentIndicationMethod), CurrentIndicationMethod, "SingleDate");
		
		If CurrentIndicationMethod <> IndicationMethodValueInList.Value Then
			
			ListItem = Items.PeriodEndClosingDateSettingMethod.ChoiceList.FindByValue(
				CurrentIndicationMethod);
			
			ShowQueryBox(
				New NotifyDescription(
					"UpdateUserDateCompletion",
					ThisObject,
					NewUser),
				MessageTextIndicationMethodNotUsed(
					IndicationMethodValueInList.Value,
					?(ListItem = Undefined, CurrentIndicationMethod, ListItem.Presentation),
					CurrentUser,
					ThisObject) + Chars.LF + Chars.LF + NStr("ru = 'Продолжить?'; en = 'Continue?'; pl = 'Kontynuować?';es_ES = '¿Continuar?';es_CO = '¿Continuar?';tr = 'Devam et?';it = 'Continuare?';de = 'Fortsetzen?'"),
				QuestionDialogMode.YesNo);
			Return;
		EndIf;
	EndIf;
	
	UpdateUserDateCompletion(Undefined, NewUser);
	
EndProcedure

&AtClient
Procedure UpdateUserDateCompletion(Response, NewUser) Export
	
	If Response = DialogReturnCode.No Then
		Filter = New Structure("User", CurrentUser);
		FoundRows = ClosingDatesUsers.FindRows(Filter);
		If FoundRows.Count() > 0 Then
			UsersCurrentRow = FoundRows[0].GetID();
			AttachIdleHandler(
				"UsersRestoreCurrentRowAfterCancelOnActivateRow", 0.1, True);
		EndIf;
		Return;
	EndIf;
	
	CurrentUser = NewUser;
	
	// Reading the current user data.
	If NewUser = Undefined Then
		PeriodEndClosingDateSettingMethod = "SingleDate";
		ClosingDates.GetItems().Clear();
		Items.UserData.CurrentPage = Items.UserNotSelectedPage;
	Else
		ReadUserData(ThisObject);
		ExpandUserData();
	EndIf;
	
	UpdateClosingDatesAvailabilityOfCurrentUser();
	
	// Locking commands Pick, Add (object) until a section is selected.
	ClosingDatesSetCommandsAvailability(False);
	
EndProcedure

&AtServer
Procedure ReadUsers()
	
	Query = New Query;
	Query.SetParameter("AllSectionsWithoutObjects",     AllSectionsWithoutObjects);
	Query.SetParameter("DataImportRestrictionDates", Parameters.DataImportRestrictionDates);
	Query.Text =
	"SELECT DISTINCT
	|	PRESENTATION(PeriodClosingDates.User) AS FullPresentation,
	|	PeriodClosingDates.User,
	|	CASE
	|		WHEN VALUETYPE(PeriodClosingDates.User) = TYPE(Enum.PeriodClosingDatesPurposeTypes)
	|			THEN 0
	|		ELSE 1
	|	END AS CommonAssignment,
	|	PRESENTATION(PeriodClosingDates.User) AS Presentation,
	|	MAX(PeriodClosingDates.Comment) AS Comment,
	|	FALSE AS NoPeriodEndClosingDate,
	|	-1 AS PictureNumber
	|FROM
	|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|WHERE
	|	NOT(PeriodClosingDates.Section <> PeriodClosingDates.Object
	|				AND VALUETYPE(PeriodClosingDates.Object) = TYPE(ChartOfCharacteristicTypes.PeriodClosingDatesSections))
	|	AND NOT(VALUETYPE(PeriodClosingDates.Object) <> TYPE(ChartOfCharacteristicTypes.PeriodClosingDatesSections)
	|				AND &AllSectionsWithoutObjects)
	|
	|GROUP BY
	|	PeriodClosingDates.User
	|
	|HAVING
	|	PeriodClosingDates.User <> UNDEFINED AND
	|	CASE
	|		WHEN VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.Users)
	|				OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.UserGroups)
	|				OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsers)
	|				OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsersGroups)
	|				OR PeriodClosingDates.User = VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllUsers)
	|			THEN &DataImportRestrictionDates = FALSE
	|		ELSE &DataImportRestrictionDates = TRUE
	|	END";
	
	// Incorrect records are excluded from the selection if the following conditions are met:
	// - object with the value of the CCT.PeriodClosingDatesSections type can be only equal to the section.
	DataExported = Query.Execute().Unload();
	
	// Filling full presentation of users.
	For Each Row In DataExported Do
		Row.Presentation       = UserPresentationText(ThisObject, Row.User);
		Row.FullPresentation = Row.Presentation;
	EndDo;
	
	// Filling a presentation of all users.
	AllUsersDetails = DataExported.Find(ValueForAllUsers, "User");
	If AllUsersDetails = Undefined Then
		AllUsersDetails = DataExported.Insert(0);
		AllUsersDetails.User = ValueForAllUsers;
		AllUsersDetails.NoPeriodEndClosingDate = True;
	EndIf;
	AllUsersDetails.Presentation       = PresentationTextForAllUsers(ThisObject);
	AllUsersDetails.FullPresentation = AllUsersDetails.Presentation;
	AllUsersDetails.Comment         = CommentTextForAllUsers();
	
	DataExported.Sort("CommonAssignment Asc, FullPresentation Asc");
	ValueToFormAttribute(DataExported, "ClosingDatesUsers");
	
	FillPicturesNumbersOfClosingDatesUsers(ThisObject);
	
	CurrentUser = ValueForAllUsers;
	
EndProcedure

&AtClient
Procedure ExpandUserData()
	
	If ShowCurrentUserSections Then
		For Each SectionDetails In ClosingDates.GetItems() Do
			Items.ClosingDates.Expand(SectionDetails.GetID(), True);
		EndDo;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure ReadUserData(Form, CurrentIndicationMethod = Undefined, Data = Undefined)
	
	If Form.SetPeriodEndClosingDate = "NoPeriodEnd" Then
		
		UnlockAllRecordsAtServer(Form.LocksAddress);
		Return;
		
	ElsIf Form.SetPeriodEndClosingDate = "ByUsers" Then
		
		FoundRows = Form.ClosingDatesUsers.FindRows(
			New Structure("User", Form.CurrentUser));
		
		If FoundRows.Count() > 0 Then
			Form.Items.CurrentUserPresentation.Title =
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Настройка для ""%1"":'; en = 'Setting for ""%1"":'; pl = 'Ustawienia do ""%1"":';es_ES = 'Ajuste para ""%1"":';es_CO = 'Ajuste para ""%1"":';tr = '""%1"" için ayarlar:';it = 'Impostazione per ""%1"":';de = 'Einstellung für ""%1"":'"), FoundRows[0].Presentation);
		EndIf;
	EndIf;
	
	Form.Items.UserData.CurrentPage =
		Form.Items.UserSelectedPage;
	
	Form.ClosingDates.GetItems().Clear();
	
	If CurrentIndicationMethod = Undefined Then
		CurrentIndicationMethod = CurrentIndicationMethodOfPeriodEndClosingDate(
			Form.CurrentUser,
			Form.SingleSection,
			Form.ValueForAllUsers,
			Form.BegOfDay,
			Data);
		
		CurrentIndicationMethod = ?(CurrentIndicationMethod = "", "SingleDate", CurrentIndicationMethod);
		If Form.PeriodEndClosingDateSettingMethod <> CurrentIndicationMethod Then
			Form.PeriodEndClosingDateSettingMethod = CurrentIndicationMethod;
		EndIf;
	EndIf;
	
	If Form.PeriodEndClosingDateSettingMethod = "SingleDate" Then
		Form.Items.DateSettingMethodBySectionsObjects.Visible = False;
		Form.Items.DateSettingMethods.CurrentPage = Form.Items.DateSettingMethodSingleDate;
		// For pinning the "Advanced features" group
		Form.Items.ClosingDates.VerticalStretch = False;
		
		FillPropertyValues(Form, Data);
		Form.EnableDataChangeBeforePeriodEndClosingDate = Form.PermissionDaysCount <> 0;
		PeriodClosingDatesInternalClientServer.SpecifyPeriodEndClosingDateSetupOnChange(Form, False);
		PeriodClosingDatesInternalClientServer.UpdatePeriodEndClosingDateDisplayOnChange(Form);
		Form.Items.PeriodEndClosingDateDetails.ReadOnly = False;
		Form.Items.PeriodEndClosingDate.ReadOnly = False;
		Form.Items.EnableDataChangeBeforePeriodEndClosingDate.ReadOnly = False;
		Form.Items.PermissionDaysCount.ReadOnly = False;
		Try
			LockUserRecordAtServer(Form.LocksAddress,
				Form.SectionEmptyRef,
				Form.SectionEmptyRef,
				Form.CurrentUser,
				True);
		Except
			Form.Items.PeriodEndClosingDateDetails.ReadOnly = True;
			Form.Items.PeriodEndClosingDate.ReadOnly = True;
			Form.Items.EnableDataChangeBeforePeriodEndClosingDate.ReadOnly = True;
			Form.Items.PermissionDaysCount.ReadOnly = True;
			
			CommonClientServer.MessageToUser(
				BriefErrorDescription(ErrorInfo()));
		EndTry;
		Return;
	EndIf;
	
	Form.Items.DateSettingMethodBySectionsObjects.Visible = True;
	Form.Items.DateSettingMethods.CurrentPage = Form.Items.DateSettingMethodBySectionsObjects;
	Form.Items.ClosingDates.VerticalStretch = True;
	
	SetCommandBarOfClosingDates(Form);
	
	TransmittedParameters = New Structure;
	TransmittedParameters.Insert("BegOfDay",                    Form.BegOfDay);
	TransmittedParameters.Insert("User",                 Form.CurrentUser);
	TransmittedParameters.Insert("SingleSection",           Form.SingleSection);
	TransmittedParameters.Insert("ShowSections",            Form.ShowSections);
	TransmittedParameters.Insert("AllSectionsWithoutObjects",        Form.AllSectionsWithoutObjects);
	TransmittedParameters.Insert("SectionsWithoutObjects",           Form.SectionsWithoutObjects);
	TransmittedParameters.Insert("SectionsTableAddress",         Form.SectionsTableAddress);
	TransmittedParameters.Insert("FormID",           Form.UUID);
	TransmittedParameters.Insert("PeriodEndClosingDateSettingMethod",    Form.PeriodEndClosingDateSettingMethod);
	TransmittedParameters.Insert("ValueForAllUsers", Form.ValueForAllUsers);
	TransmittedParameters.Insert("DataImportRestrictionDates",    Form.Parameters.DataImportRestrictionDates);
	TransmittedParameters.Insert("LocksAddress", Form.LocksAddress);
	
	UserData = Undefined;
	ReadUserDataAtServer(TransmittedParameters,
		UserData, Form.ShowCurrentUserSections);
	
	// Importing user data to the collection.
	RowsCollection = Form.ClosingDates.GetItems();
	RowsCollection.Clear();
	For Each Row In UserData Do
		NewRow = RowsCollection.Add();
		FillPropertyValues(NewRow, Row.Value);
		NewRow.PeriodEndClosingDateDetailsPresentation = DetailsPresentationOfPeriodEndClosingDate(NewRow);
		SubstringsCollection = NewRow.GetItems();
		
		For Each Substring In Row.Value.SubstringsList Do
			NewSubstring = SubstringsCollection.Add();
			FillPropertyValues(NewSubstring, Substring.Value);
			FillByInternalDetailsOfPeriodEndClosingDate(
				NewSubstring, NewSubstring.PeriodEndClosingDateDetails);
			
			NewSubstring.PeriodEndClosingDateDetailsPresentation =
				DetailsPresentationOfPeriodEndClosingDate(NewSubstring);
		EndDo;
		
		If NewRow.IsSection Then
			NewRow.SectionWithoutObjects =
				Form.SectionsWithoutObjects.Find(NewRow.Section) <> Undefined;
		EndIf;
	EndDo;
	
	// Setting the field of the ClosingDates form.
	If Form.ShowCurrentUserSections Then
		If Form.AllSectionsWithoutObjects Then
			// Data is used only by the Section dimension.
			// Object dimension is filled in with the Section dimension value.
			// No object display is required.
			Form.Items.ClosingDatesFullPresentation.Title = NStr("ru = 'Раздел'; en = 'Section'; pl = 'Rozdział';es_ES = 'Sección';es_CO = 'Sección';tr = 'Bölüm';it = 'Sezione';de = 'Abschnitt'");
			Form.Items.ClosingDates.Representation = TableRepresentation.List;
			
		Else
			Form.Items.ClosingDatesFullPresentation.Title = NStr("ru = 'Раздел, объект'; en = 'Section, object'; pl = 'Rozdział, obiekt';es_ES = 'Sección, objeto';es_CO = 'Sección, objeto';tr = 'Bölüm, nesne';it = 'Sezione, oggetto';de = 'Abschnitt, Objekt'");
			Form.Items.ClosingDates.Representation = TableRepresentation.Tree;
		EndIf;
	Else
		ObjectsTypesPresentations = "";
		SectionObjectsTypes = Form.Sections.Get(Form.SingleSection).ObjectsTypes;
		If SectionObjectsTypes <> Undefined Then
			For Each TypeProperties In SectionObjectsTypes Do
				ObjectsTypesPresentations = ObjectsTypesPresentations + Chars.LF
					+ TypeProperties.Presentation;
			EndDo;
		EndIf;
		Form.Items.ClosingDatesFullPresentation.Title = TrimAll(ObjectsTypesPresentations);
		Form.Items.ClosingDates.Representation = TableRepresentation.List;
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure ReadUserDataAtServer(Val Form, UserData, ShowCurrentUserSections)
	
	UnlockAllRecordsAtServer(Form.LocksAddress);
	
	ShowCurrentUserSections
			  = Form.ShowSections
			Or Form.PeriodEndClosingDateSettingMethod = "BySections"
			Or Form.PeriodEndClosingDateSettingMethod = "BySectionsAndObjects";
	
	// Preparing a value tree of period-end closing dates.
	If ShowCurrentUserSections Then
		ReadClosingDates = ReadUserDataWithSections(
			Form.User,
			Form.AllSectionsWithoutObjects,
			Form.SectionsWithoutObjects,
			Form.SectionsTableAddress,
			Form.BegOfDay,
			Form.DataImportRestrictionDates);
	Else
		ReadClosingDates = ReadUserDataWithoutSections(
			Form.User, Form.SingleSection);
	EndIf;
	
	UserData = New ValueList;
	RowFields = "FullPresentation, Presentation, Section, Object,
	             |PeriodEndClosingDate, PeriodEndClosingDateDetails, PermissionDaysCount,
	             |NoPeriodEndClosingDate, IsSection, SubstringsList, RecordExists";
	
	For Each Row In ReadClosingDates.Rows Do
		StringStructure = New Structure(RowFields);
		FillPropertyValues(StringStructure, Row);
		StringStructure.SubstringsList = New ValueList;
		For Each Substring In Row.Rows Do
			SubstringStructure = New Structure(RowFields);
			FillPropertyValues(SubstringStructure, Substring);
			StringStructure.SubstringsList.Add(SubstringStructure);
		EndDo;
		UserData.Add(StringStructure);
	EndDo;
	
EndProcedure

&AtServerNoContext
Function ReadUserDataWithSections(Val User,
                                              Val AllSectionsWithoutObjects,
                                              Val SectionsWithoutObjects,
                                              Val SectionsTableAddress,
                                              Val BegOfDay,
                                              Val DataImportRestrictionDates)
	
	// Preparing a value tree of period-end closing dates with the first level by sections.
	// 
	Query = New Query;
	Query.SetParameter("User",              User);
	Query.SetParameter("AllSectionsWithoutObjects",     AllSectionsWithoutObjects);
	Query.SetParameter("DataImportRestrictionDates", DataImportRestrictionDates);
	Query.SetParameter("SectionsTable", GetFromTempStorage(SectionsTableAddress));
	Query.Text =
	"SELECT DISTINCT
	|	SectionsTable.Ref AS Ref,
	|	SectionsTable.Presentation AS Presentation,
	|	SectionsTable.IsCommonDate AS IsCommonDate
	|INTO SectionsTable
	|FROM
	|	&SectionsTable AS SectionsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Sections.Ref AS Ref,
	|	Sections.Presentation AS Presentation,
	|	Sections.IsCommonDate AS IsCommonDate
	|INTO Sections
	|FROM
	|	(SELECT
	|		SectionsTable.Ref AS Ref,
	|		SectionsTable.Presentation AS Presentation,
	|		SectionsTable.IsCommonDate AS IsCommonDate
	|	FROM
	|		SectionsTable AS SectionsTable
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		PeriodClosingDates.Section,
	|		PeriodClosingDates.Section.Description,
	|		FALSE
	|	FROM
	|		InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|			LEFT JOIN SectionsTable AS SectionsTable
	|			ON PeriodClosingDates.Section = SectionsTable.Ref
	|	WHERE
	|		SectionsTable.Ref IS NULL
	|		AND PeriodClosingDates.User <> UNDEFINED
	|		AND CASE
	|				WHEN VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.Users)
	|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.UserGroups)
	|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsers)
	|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsersGroups)
	|						OR PeriodClosingDates.User = VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllUsers)
	|					THEN &DataImportRestrictionDates = FALSE
	|				ELSE &DataImportRestrictionDates = TRUE
	|			END) AS Sections
	|
	|INDEX BY
	|	Sections.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Sections.Ref AS Section,
	|	Sections.IsCommonDate AS IsCommonDate,
	|	Sections.Presentation AS SectionPresentation,
	|	PeriodClosingDates.Object AS Object,
	|	PRESENTATION(PeriodClosingDates.Object) AS FullPresentation,
	|	PRESENTATION(PeriodClosingDates.Object) AS Presentation,
	|	CASE
	|		WHEN PeriodClosingDates.Object IS NULL
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS NoPeriodEndClosingDate,
	|	PeriodClosingDates.PeriodEndClosingDate AS PeriodEndClosingDate,
	|	PeriodClosingDates.PeriodEndClosingDateDetails AS PeriodEndClosingDateDetails,
	|	FALSE AS IsSection,
	|	0 AS PermissionDaysCount,
	|	TRUE AS RecordExists
	|FROM
	|	Sections AS Sections
	|		LEFT JOIN InformationRegister.PeriodClosingDates AS PeriodClosingDates
	|		ON Sections.Ref = PeriodClosingDates.Section
	|			AND (PeriodClosingDates.User = &User)
	|			AND (NOT(PeriodClosingDates.Section <> PeriodClosingDates.Object
	|					AND VALUETYPE(PeriodClosingDates.Object) = TYPE(ChartOfCharacteristicTypes.PeriodClosingDatesSections)))
	|			AND (NOT(VALUETYPE(PeriodClosingDates.Object) <> TYPE(ChartOfCharacteristicTypes.PeriodClosingDatesSections)
	|					AND &AllSectionsWithoutObjects))
	|
	|ORDER BY
	|	IsCommonDate DESC,
	|	SectionPresentation
	|TOTALS
	|	MAX(IsCommonDate),
	|	MAX(SectionPresentation),
	|	MIN(NoPeriodEndClosingDate),
	|	MAX(IsSection)
	|BY
	|	Section";
	
	ReadClosingDates = Query.Execute().Unload(QueryResultIteration.ByGroups);
	
	For Each Row In ReadClosingDates.Rows Do
		Row.Presentation = Row.SectionPresentation;
		Row.Object    = Row.Section;
		Row.IsSection = True;
		SectionRow = Row.Rows.Find(Row.Section, "Object");
		If SectionRow <> Undefined Then
			Row.RecordExists = True;
			Row.PeriodEndClosingDate = PeriodClosingDatesInternal.PeriodEndClosingDateByDetails(
				SectionRow.PeriodEndClosingDateDetails, SectionRow.PeriodEndClosingDate, BegOfDay);
			
			If ValueIsFilled(SectionRow.PeriodEndClosingDateDetails) Then
				FillByInternalDetailsOfPeriodEndClosingDate(Row, SectionRow.PeriodEndClosingDateDetails);
			Else
				Row.PeriodEndClosingDateDetails = "CustomDate";
			EndIf;
			Row.Rows.Delete(SectionRow);
		Else
			If Row.Rows.Count() = 1
			   AND Row.Rows[0].Object = Null Then
				
				Row.Rows.Delete(Row.Rows[0]);
			EndIf;
		EndIf;
		Row.FullPresentation = Row.Presentation;
		For Each Substring In Row.Rows Do
			Substring.PeriodEndClosingDate = PeriodClosingDatesInternal.PeriodEndClosingDateByDetails(
				Substring.PeriodEndClosingDateDetails, Substring.PeriodEndClosingDate, BegOfDay);
		EndDo;
	EndDo;
	
	Return ReadClosingDates;
	
EndFunction

&AtServerNoContext
Function ReadUserDataWithoutSections(Val User, Val SingleSection)
	
	// Value tree with the first level by objects.
	BeginTransaction();
	Try
		Query = New Query;
		Query.SetParameter("User",           User);
		Query.SetParameter("SingleSection",     SingleSection);
		Query.SetParameter("CommonDatePresentation", CommonDatePresentationText());
		Query.Text =
		"SELECT ALLOWED
		|	VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef) AS Section,
		|	VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef) AS Object,
		|	&CommonDatePresentation AS FullPresentation,
		|	&CommonDatePresentation AS Presentation,
		|	ISNULL(SingleDate.PeriodEndClosingDate, DATETIME(1, 1, 1, 0, 0, 0)) AS PeriodEndClosingDate,
		|	ISNULL(SingleDate.PeriodEndClosingDateDetails, """") AS PeriodEndClosingDateDetails,
		|	TRUE AS IsSection,
		|	0 AS PermissionDaysCount,
		|	TRUE AS RecordExists
		|FROM
		|	(SELECT
		|		TRUE AS TrueValue) AS Value
		|		LEFT JOIN (SELECT
		|			PeriodClosingDates.PeriodEndClosingDate AS PeriodEndClosingDate,
		|			PeriodClosingDates.PeriodEndClosingDateDetails AS PeriodEndClosingDateDetails
		|		FROM
		|			InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|		WHERE
		|			PeriodClosingDates.User = &User
		|			AND PeriodClosingDates.Section = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
		|			AND PeriodClosingDates.Object = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)) AS SingleDate
		|		ON (TRUE)
		|
		|UNION ALL
		|
		|SELECT
		|	&SingleSection,
		|	PeriodClosingDates.Object,
		|	PRESENTATION(PeriodClosingDates.Object),
		|	PRESENTATION(PeriodClosingDates.Object),
		|	PeriodClosingDates.PeriodEndClosingDate,
		|	PeriodClosingDates.PeriodEndClosingDateDetails,
		|	FALSE,
		|	0,
		|	TRUE
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	PeriodClosingDates.User = &User
		|	AND PeriodClosingDates.Section = &SingleSection
		|	AND VALUETYPE(PeriodClosingDates.Object) <> TYPE(ChartOfCharacteristicTypes.PeriodClosingDatesSections)";
		
		ReadClosingDates = Query.Execute().Unload(QueryResultIteration.ByGroups);
	
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Index = ReadClosingDates.Rows.Count()-1;
	While Index >= 0 Do
		Row = ReadClosingDates.Rows[Index];
		FillByInternalDetailsOfPeriodEndClosingDate(Row, Row.PeriodEndClosingDateDetails);
		Index = Index - 1;
	EndDo;
	
	Return ReadClosingDates;
	
EndFunction

&AtServerNoContext
Procedure LockUserRecordSetAtServer(Val User, Val LocksAddress, DataDetails = Undefined)
	
	BeginTransaction();
	Try
		Query = New Query;
		Query.SetParameter("User", User);
		Query.Text =
		"SELECT
		|	PeriodClosingDates.Section,
		|	PeriodClosingDates.Object,
		|	PeriodClosingDates.User,
		|	PeriodClosingDates.PeriodEndClosingDate,
		|	PeriodClosingDates.PeriodEndClosingDateDetails,
		|	PeriodClosingDates.Comment
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	PeriodClosingDates.User = &User";
		
		DataExported = Query.Execute().Unload();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Locks = GetFromTempStorage(LocksAddress);
	Try
		For Each RecordDetails In DataExported Do
			If LockRecordAtServer(RecordDetails, LocksAddress) Then
				If DataDetails <> Undefined Then
					// Rereading fields PeriodEndClosingDate, PeriodEndClosingDateDetails, and Comment.
					If Locks.NoSectionsAndObjects Then
						If RecordDetails.Section = Locks.SectionEmptyRef
						   AND RecordDetails.Object = Locks.SectionEmptyRef Then
							DataDetails.PeriodEndClosingDate         = RecordDetails.PeriodEndClosingDate;
							DataDetails.PeriodEndClosingDateDetails = RecordDetails.PeriodEndClosingDateDetails;
							DataDetails.Comment         = RecordDetails.Comment;
						EndIf;
					Else
						DataDetails.Comment = RecordDetails.Comment;
					EndIf;
				EndIf;
			EndIf;
		EndDo;
	Except
		UnlockAllRecordsAtServer(LocksAddress);
		Raise;
	EndTry;
	
EndProcedure

&AtServerNoContext
Procedure UnlockAllRecordsAtServer(LocksAddress)
	
	Locks = GetFromTempStorage(LocksAddress);
	RecordKeyValues = New Structure("Section, Object, User");
	Try
		Index = Locks.Content.Count() - 1;
		While Index >= 0 Do
			FillPropertyValues(RecordKeyValues, Locks.Content[Index]);
			RecordKey = InformationRegisters.PeriodClosingDates.CreateRecordKey(RecordKeyValues);
			UnlockDataForEdit(RecordKey, Locks.FormID);
			Locks.Content.Delete(Index);
			Index = Index - 1;
		EndDo;
	Except
		PutToTempStorage(Locks, LocksAddress);
		Raise;
	EndTry;
	PutToTempStorage(Locks, LocksAddress);
	
EndProcedure

&AtServerNoContext
Function LockRecordAtServer(RecordKeyDetails, LocksAddress)
	
	Locks = GetFromTempStorage(LocksAddress);
	RecordKeyValues = New Structure("Section, Object, User");
	FillPropertyValues(RecordKeyValues, RecordKeyDetails);
	RecordKey = InformationRegisters.PeriodClosingDates.CreateRecordKey(RecordKeyValues);
	LockDataForEdit(RecordKey, , Locks.FormID);
	LockAdded = False;
	If Locks.Content.FindRows(RecordKeyValues) = 0 Then
		FillPropertyValues(Locks.Content.Add(), RecordKeyValues);
		LockAdded = True;
	EndIf;
	PutToTempStorage(Locks, LocksAddress);
	
	Return LockAdded;
	
EndFunction

&AtServerNoContext
Function ReplaceUserRecordSet(OldUser, NewUser, LocksAddress)
	
	Locks = GetFromTempStorage(LocksAddress);
	
	If OldUser <> Undefined Then
		LockUserRecordSetAtServer(OldUser, LocksAddress);
	EndIf;
	LockUserRecordSetAtServer(NewUser, LocksAddress);
	
	RecordSet = InformationRegisters.PeriodClosingDates.CreateRecordSet();
	RecordSet.Filter.User.Set(NewUser, True);
	RecordSet.Read();
	If RecordSet.Count() > 0 Then
		Return False;
	EndIf;
	
	If OldUser <> Undefined Then
		BeginTransaction();
		Try
			RecordSet.Filter.User.Set(OldUser, True);
			RecordSet.Read();
			UserData = RecordSet.Unload();
			RecordSet.Clear();
			RecordSet.Write();
			
			UserData.FillValues(NewUser, "User");
			RecordSet.Filter.User.Set(NewUser, True);
			RecordSet.Load(UserData);
			RecordSet.Write();
			
			CommitTransaction();
		Except
			RollbackTransaction();
			UnlockAllRecordsAtServer(LocksAddress);
			Raise;
		EndTry;
	Else
		LockAndWriteBlankDates(LocksAddress,
			Locks.SectionEmptyRef, Locks.SectionEmptyRef, NewUser, "");
	EndIf;
	
	UnlockAllRecordsAtServer(LocksAddress);
	
	Return True;
	
EndFunction

&AtServerNoContext
Procedure DeleteUserRecordSet(Val User, Val LocksAddress)
	
	LockUserRecordSetAtServer(User, LocksAddress);
	
	RecordSet = InformationRegisters.PeriodClosingDates.CreateRecordSet();
	RecordSet.Filter.User.Set(User, True);
	RecordSet.Write();
	
	UnlockAllRecordsAtServer(LocksAddress);
	
EndProcedure

&AtServerNoContext
Procedure WriteComment(User, Comment);
	
	RecordSet = InformationRegisters.PeriodClosingDates.CreateRecordSet();
	RecordSet.Filter.User.Set(User, True);
	RecordSet.Read();
	UserData = RecordSet.Unload();
	UserData.FillValues(Comment, "Comment");
	RecordSet.Load(UserData);
	RecordSet.Write();
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateReadPropertiesValues(CurrentPropertiesValues, ReadProperties, CommentCurrentData = False)
	
	If ReadProperties.Comment <> Undefined Then
		
		If CommentCurrentData = False Then
			CurrentPropertiesValues.Comment = ReadProperties.Comment;
			
		ElsIf CommentCurrentData <> Undefined Then
			CommentCurrentData.Comment = ReadProperties.Comment;
		EndIf;
	EndIf;
	
	If ReadProperties.PeriodEndClosingDate <> Undefined Then
		CurrentPropertiesValues.PeriodEndClosingDate              = ReadProperties.PeriodEndClosingDate;
		CurrentPropertiesValues.PeriodEndClosingDateDetails      = ReadProperties.PeriodEndClosingDateDetails;
		CurrentPropertiesValues.PermissionDaysCount = ReadProperties.PermissionDaysCount;
		CalculatedProperties = New Structure;
		CalculatedProperties.Insert("PeriodEndClosingDateDetailsPresentation", DetailsPresentationOfPeriodEndClosingDate(ReadProperties));
		FillPropertyValues(CurrentPropertiesValues, CalculatedProperties);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function GetCurrentPropertiesValues(CurrentData, CommentCurrentData)
	
	Properties = New Structure;
	Properties.Insert("PeriodEndClosingDate");
	Properties.Insert("PeriodEndClosingDateDetails");
	Properties.Insert("PermissionDaysCount");
	Properties.Insert("Comment");
	
	If CommentCurrentData <> Undefined Then
		Properties.Comment = CommentCurrentData.Comment;
	EndIf;
	
	Properties.PeriodEndClosingDate              = CurrentData.PeriodEndClosingDate;
	Properties.PeriodEndClosingDateDetails      = CurrentData.PeriodEndClosingDateDetails;
	Properties.PermissionDaysCount = CurrentData.PermissionDaysCount;
	
	Return Properties;
	
EndFunction

&AtServerNoContext
Function LockUserRecordAtServer(Val LocksAddress, Val Section, Val Object,
			 Val User, Val UnlockPreviouslyLocked = False)
	
	If UnlockPreviouslyLocked Then
		UnlockAllRecordsAtServer(LocksAddress);
	EndIf;
	
	RecordKeyValues = New Structure;
	RecordKeyValues.Insert("Section",       Section);
	RecordKeyValues.Insert("Object",       Object);
	RecordKeyValues.Insert("User", User);
	
	LockRecordAtServer(RecordKeyValues, LocksAddress);
	
	RecordManager = InformationRegisters.PeriodClosingDates.CreateRecordManager();
	FillPropertyValues(RecordManager, RecordKeyValues);
	RecordManager.Read();
	
	ReadProperties = New Structure;
	ReadProperties.Insert("PeriodEndClosingDate");
	ReadProperties.Insert("PeriodEndClosingDateDetails");
	ReadProperties.Insert("PermissionDaysCount");
	ReadProperties.Insert("Comment");
	
	If RecordManager.Selected() Then
		Locks = GetFromTempStorage(LocksAddress);
		ReadProperties.PeriodEndClosingDate = PeriodClosingDatesInternal.PeriodEndClosingDateByDetails(
			RecordManager.PeriodEndClosingDateDetails, RecordManager.PeriodEndClosingDate, Locks.BegOfDay);
		
		ReadProperties.Comment = RecordManager.Comment;
		FillByInternalDetailsOfPeriodEndClosingDate(
			ReadProperties, RecordManager.PeriodEndClosingDateDetails);
	Else
		BeginTransaction();
		Try
			Query = New Query;
			Query.SetParameter("User", RecordKeyValues.User);
			Query.Text =
			"SELECT TOP 1
			|	PeriodClosingDates.Comment
			|FROM
			|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
			|WHERE
			|	PeriodClosingDates.User = &User";
			Selection = Query.Execute().Select();
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		If Selection.Next() Then
			ReadProperties.Comment = Selection.Comment;
		EndIf;
	EndIf;
	
	Return ReadProperties;
	
EndFunction

&AtServerNoContext
Function ReplaceObjectInUserRecordAtServer(Val Section, Val OldObject, Val NewObject, Val User,
			CurrentPropertiesValues, LocksAddress)
	
	// Locking a new record and checking if it exists.
	LockUserRecordAtServer(LocksAddress, Section, NewObject, User);
	
	RecordKeyValues = New Structure;
	RecordKeyValues.Insert("Section",       Section);
	RecordKeyValues.Insert("Object",       NewObject);
	RecordKeyValues.Insert("User", User);
	
	RecordManager = InformationRegisters.PeriodClosingDates.CreateRecordManager();
	FillPropertyValues(RecordManager, RecordKeyValues);
	RecordManager.Read();
	If RecordManager.Selected() Then
		UnlockAllRecordsAtServer(LocksAddress);
		Return False;
	EndIf;
	
	If ValueIsFilled(OldObject) Then
		// Locking an old record
		ReadProperties = LockUserRecordAtServer(LocksAddress,
			Section, OldObject, User);
		
		UpdateReadPropertiesValues(CurrentPropertiesValues, ReadProperties);
		
		RecordKeyValues.Object = OldObject;
		FillPropertyValues(RecordManager, RecordKeyValues);
		RecordManager.Read();
		If RecordManager.Selected() Then
			RecordManager.Delete();
		EndIf;
	EndIf;
	
	If ValueIsFilled(CurrentPropertiesValues.PeriodEndClosingDateDetails) Then
		RecordManager.Section              = Section;
		RecordManager.Object              = NewObject;
		RecordManager.User        = User;
		RecordManager.PeriodEndClosingDate         = InternalPeriodEndClosingDate(CurrentPropertiesValues);
		RecordManager.PeriodEndClosingDateDetails = InternalDetailsOfPeriodEndClosingDate(CurrentPropertiesValues);
		RecordManager.Comment         = CurrentPropertiesValues.Comment;
		RecordManager.Write();
	EndIf;
	
	UnlockAllRecordsAtServer(LocksAddress);
	
	Return True;
	
EndFunction

&AtClient
Function CurrentSection(CurrentData = Undefined, ObjectsSection = False)
	
	If CurrentData = Undefined Then
		CurrentData = Items.ClosingDates.CurrentData;
	EndIf;
	
	If NoSectionsAndObjects
	 Or PeriodEndClosingDateSettingMethod = "SingleDate" Then
		
		CurrentSection = SectionEmptyRef;
		
	ElsIf ShowCurrentUserSections Then
		If CurrentData.IsSection Then
			CurrentSection = CurrentData.Section;
		Else
			CurrentSection = CurrentData.GetParent().Section;
		EndIf;
		
	Else // The only section hidden from a user.
		If CurrentData <> Undefined
		   AND CurrentData.Section = SectionEmptyRef
		   AND Not ObjectsSection Then
			
			CurrentSection = SectionEmptyRef;
		Else
			CurrentSection = SingleSection;
		EndIf;
	EndIf;
	
	Return CurrentSection;
	
EndFunction

&AtClient
Procedure WriteCommonPeriodEndClosingDateWithDetails();
	
	Data = CurrentDataOfCommonPeriodEndClosingDate();
	WriteDetailsAndPeriodEndClosingDate(Data);
	RecordExists = Data.RecordExists;
	
	UpdateClosingDatesAvailabilityOfCurrentUser();
	
EndProcedure

&AtClient
Procedure UpdatePeriodEndClosingDateDisplayOnChangeIdleHandler()
	
	PeriodClosingDatesInternalClientServer.UpdatePeriodEndClosingDateDisplayOnChange(ThisObject);
	
EndProcedure

&AtClient
Function CurrentDataOfCommonPeriodEndClosingDate()
	
	Data = New Structure;
	Data.Insert("Object",                   SectionEmptyRef);
	Data.Insert("Section",                   SectionEmptyRef);
	Data.Insert("PeriodEndClosingDateDetails",      PeriodEndClosingDateDetails);
	Data.Insert("PermissionDaysCount", PermissionDaysCount);
	Data.Insert("PeriodEndClosingDate",              PeriodEndClosingDate);
	Data.Insert("RecordExists",         RecordExists);
	
	Return Data;
	
EndFunction

&AtClient
Procedure WriteDetailsAndPeriodEndClosingDate(CurrentData = Undefined)
	
	If CurrentData = Undefined Then
		CurrentData = Items.ClosingDates.CurrentData;
	EndIf;
	
	If PeriodEndClosingDateSet(CurrentData, CurrentUser, True) Then
		// Writing details or a period-end closing date.
		Comment = CurrentUserComment(ThisObject);
		RecordPeriodEndClosingDateWithDetails(
			CurrentData.Section,
			CurrentData.Object,
			CurrentUser,
			InternalPeriodEndClosingDate(CurrentData),
			InternalDetailsOfPeriodEndClosingDate(CurrentData),
			Comment);
		CurrentData.RecordExists = True;
	Else
		DeleteUserRecord(LocksAddress,
			CurrentData.Section,
			CurrentData.Object,
			CurrentUser);
		
		CurrentData.RecordExists = False;
	EndIf;
	
	NotifyChanged(Type("InformationRegisterRecordKey.PeriodClosingDates"));
	
EndProcedure

&AtServerNoContext
Procedure RecordPeriodEndClosingDateWithDetails(Val Section, Val Object, Val User, Val PeriodEndClosingDate, Val InternalDetailsOfPeriodEndClosingDate, Val Comment)
	
	RecordManager = InformationRegisters.PeriodClosingDates.CreateRecordManager();
	RecordManager.Section              = Section;
	RecordManager.Object              = Object;
	RecordManager.User        = User;
	RecordManager.PeriodEndClosingDate         = PeriodEndClosingDate;
	RecordManager.PeriodEndClosingDateDetails = InternalDetailsOfPeriodEndClosingDate;
	RecordManager.Comment = Comment;
	RecordManager.Write();
	
EndProcedure

&AtServerNoContext
Procedure DeleteUserRecord(Val LocksAddress, Val Section, Val Object, Val User)
	
	RecordManager = InformationRegisters.PeriodClosingDates.CreateRecordManager();
	
	If TypeOf(Object) = Type("Array") Then
		Objects = Object;
	Else
		Objects = New Array;
		Objects.Add(Object);
	EndIf;
	
	For Each CurrentObject In Objects Do
		LockUserRecordAtServer(LocksAddress,
			Section, CurrentObject, User);
	EndDo;
	
	For Each CurrentObject In Objects Do
		RecordManager.Section = Section;
		RecordManager.Object = CurrentObject;
		RecordManager.User = User;
		RecordManager.Read();
		If RecordManager.Selected() Then
			RecordManager.Delete();
		EndIf;
	EndDo;
	
	UnlockAllRecordsAtServer(LocksAddress);
	
EndProcedure

&AtClient
Procedure UpdateClosingDatesAvailabilityOfCurrentUser()
	
	If Items.Users.CurrentData = Undefined Then
		Return;
	EndIf;
	CurrentData = Items.Users.CurrentData;
	
	NoPeriodEndClosingDate = True;
	If PeriodEndClosingDateSettingMethod = "SingleDate" Then
		Data = CurrentDataOfCommonPeriodEndClosingDate();
		NoPeriodEndClosingDate = Not PeriodEndClosingDateSet(Data, CurrentUser);
	Else
		For Each Row In ClosingDates.GetItems() Do
			WithoutSectionPeriodEndClosingDate = True;
			If PeriodEndClosingDateSet(Row, CurrentUser) Then
				WithoutSectionPeriodEndClosingDate = False;
			EndIf;
			For Each SubordinateRow In Row.GetItems() Do
				If PeriodEndClosingDateSet(SubordinateRow, CurrentUser) Then
					SubordinateRow.NoPeriodEndClosingDate = False;
					WithoutSectionPeriodEndClosingDate = False;
				Else
					SubordinateRow.NoPeriodEndClosingDate = True;
				EndIf;
			EndDo;
			Row.FullPresentation = Row.Presentation;
			Row.NoPeriodEndClosingDate = WithoutSectionPeriodEndClosingDate;
			NoPeriodEndClosingDate = NoPeriodEndClosingDate AND WithoutSectionPeriodEndClosingDate;
		EndDo;
	EndIf;
	
	CurrentData.NoPeriodEndClosingDate = NoPeriodEndClosingDate;
	
EndProcedure

&AtClient
Procedure UsersOnStartEditIdleHandler()
	
	SelectPickUsers();
	
EndProcedure

&AtClient
Procedure SelectPickUsers(Select = False)
	
	If Parameters.DataImportRestrictionDates Then
		SelectPickExchangePlansNodes(Select);
		Return;
	EndIf;
	
	If UseExternalUsers Then
		ShowTypeSelectionUsersOrExternalUsers(
			New NotifyDescription("SelectPickUsersCompletion", ThisObject, Select));
	Else
		SelectPickUsersCompletion(False, Select);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectPickUsersCompletion(ExternalUsersSelectionAndPickup, Select) Export
	
	If ExternalUsersSelectionAndPickup = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow",
		?(Items.Users.CurrentData = Undefined,
		  Undefined,
		  Items.Users.CurrentData.User));
	
	If ExternalUsersSelectionAndPickup Then
		FormParameters.Insert("SelectExternalUsersGroups", True);
	Else
		FormParameters.Insert("UsersGroupsSelection", True);
	EndIf;
	
	If Select Then
		FormParameters.Insert("CloseOnChoice", False);
		FormOwner = Items.Users;
	Else
		FormOwner = Items.UsersFullPresentation;
	EndIf;
	
	If ExternalUsersSelectionAndPickup Then
	
		If CatalogExternalUsersAvailable Then
			OpenForm("Catalog.ExternalUsers.ChoiceForm", FormParameters, FormOwner);
		Else
			ShowMessageBox(, NStr("ru = 'Недостаточно прав для выбора внешних пользователей.'; en = 'Insufficient rights to select external users.'; pl = 'Niewystarczające uprawnienia do wyboru użytkowników zewnętrznych.';es_ES = 'Insuficientes derechos para seleccionar usuarios externos.';es_CO = 'Insuficientes derechos para seleccionar usuarios externos.';tr = 'Harici kullanıcıları seçmek için yetersiz hak.';it = 'Autorizzazioni insufficienti per la selezione di utenti esterni.';de = 'Unzureichende Rechte zur Auswahl externer Benutzer.'"));
		EndIf;
	Else
		OpenForm("Catalog.Users.ChoiceForm", FormParameters, FormOwner);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectPickExchangePlansNodes(Select)
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("SelectAllNodes", True);
	FormParameters.Insert("ExchangePlansForSelection", UserTypesList.UnloadValues());
	FormParameters.Insert("CurrentRow",
		?(Items.Users.CurrentData = Undefined,
		  Undefined,
		  Items.Users.CurrentData.User));
	
	If Select Then
		FormParameters.Insert("CloseOnChoice", False);
		FormParameters.Insert("MultipleChoice", True);
		FormOwner = Items.Users;
	Else
		FormOwner = Items.UsersFullPresentation;
	EndIf;
	
	OpenForm("CommonForm.SelectExchangePlanNodes", FormParameters, FormOwner);
	
EndProcedure

&AtServerNoContext
Function GenerateUserSelectionData(Val Text,
                                             Val IncludeGroups = True,
                                             Val IncludeExternalUsers = Undefined,
                                             Val NoUsers = False)
	
	Return Users.GenerateUserSelectionData(
		Text,
		IncludeGroups,
		IncludeExternalUsers,
		NoUsers);
	
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
			HeaderTextDataTypeSelection(),
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

&AtClientAtServerNoContext
Procedure FillPicturesNumbersOfClosingDatesUsers(Form, CurrentRow = Undefined)
	
	Rows = New Array;
	If CurrentRow = Undefined Then
		Rows = Form.ClosingDatesUsers;
	Else
		Rows.Add(Form.ClosingDatesUsers.FindByID(CurrentRow));
	EndIf;
	
	RowsArray = New Array;
	For Each Row In Rows Do
		RowProperties = New Structure("User, PictureNumber");
		FillPropertyValues(RowProperties, Row);
		RowsArray.Add(RowProperties);
	EndDo;
	
	FillPicturesNumbersOfClosingDatesUsersAtServer(RowsArray,
		Form.Parameters.DataImportRestrictionDates);
	
	Index = Rows.Count()-1;
	While Index >= 0 Do
		FillPropertyValues(Rows[Index], RowsArray[Index], "PictureNumber");
		Index = Index - 1;
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure FillPicturesNumbersOfClosingDatesUsersAtServer(RowsArray, DataImportRestrictionDates)
	
	If DataImportRestrictionDates Then
		
		For Each Row In RowsArray Do
			
			If Row.User =
					Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases Then
				
				Row.PictureNumber = -1;
				
			ElsIf Not ValueIsFilled(Row.User) Then
				Row.PictureNumber = 0;
				
			ElsIf Row.User
			        = Common.ObjectManagerByRef(Row.User).ThisNode() Then
				
				Row.PictureNumber = 1;
			Else
				Row.PictureNumber = 2;
			EndIf;
		EndDo;
	Else
		Users.FillUserPictureNumbers(
			RowsArray, "User", "PictureNumber");
	EndIf;
	
EndProcedure

&AtClient
Procedure IdleHandlerSelectObjects()
	
	SelectPickObjects();
	
EndProcedure

&AtClient
Procedure ClosingDatesSetCommandsAvailability(Val CommandsAvailability)
	
	Items.ClosingDatesChange.Enabled                = CommandsAvailability;
	Items.ClosingDatesContextMenuChange.Enabled = CommandsAvailability;
	
	If PeriodEndClosingDateSettingMethod = "ByObjects" Then
		CommandsAvailability = True;
	EndIf;
	
	Items.ClosingDatesPick.Enabled = CommandsAvailability;
	
	Items.ClosingDatesAdd.Enabled                = CommandsAvailability;
	Items.PeriodEndClosingDatesContextMenuAdd.Enabled = CommandsAvailability;
	
EndProcedure

&AtClient
Procedure SelectPickObjects(Select = False)
	
	// Select data type
	CurrentSection = CurrentSection(, True);
	If CurrentSection = SectionEmptyRef Then
		ShowMessageBox(, MessageTextInSelectedSectionClosingDatesForObjectsNotSet(CurrentSection));
		Return;
	EndIf;
	SectionObjectsTypes = Sections.Get(CurrentSection).ObjectsTypes;
	If SectionObjectsTypes = Undefined Or SectionObjectsTypes.Count() = 0 Then
		ShowMessageBox(, MessageTextInSelectedSectionClosingDatesForObjectsNotSet(CurrentSection));
		Return;
	EndIf;
	
	TypesList = New ValueList;
	For Each TypeProperties In SectionObjectsTypes Do
		TypesList.Add(TypeProperties.FullName, TypeProperties.Presentation);
	EndDo;
	
	If TypesList.Count() = 1 Then
		SelectPickObjectsCompletion(TypesList[0], Select);
	Else
		TypesList.ShowChooseItem(
			New NotifyDescription("SelectPickObjectsCompletion", ThisObject, Select),
			HeaderTextDataTypeSelection(),
			TypesList[0]);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectPickObjectsCompletion(Item, Select) Export
	
	If Item = Undefined Then
		Return;
	EndIf;
	
	CurrentData = Items.ClosingDates.CurrentData;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode", True);
	FormParameters.Insert("CurrentRow",
		?(CurrentData = Undefined, Undefined, CurrentData.Object));
	
	If Select Then
		FormParameters.Insert("CloseOnChoice", False);
		FormOwner = Items.ClosingDates;
	Else
		FormOwner = Items.ClosingDatesFullPresentation;
	EndIf;
	
	OpenForm(Item.Value + ".ChoiceForm", FormParameters, FormOwner);
	
EndProcedure

&AtClient
Function NotificationTextOfUnusedSettingModes()
	
	If Not ValueIsFilled(CurrentUser) Then
		Return "";
	EndIf;
	
	SetClosingDatesInDatabase = "";
	IndicationMethodInDatabase = "";
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("BegOfDay",                    BegOfDay);
	AdditionalParameters.Insert("DataImportRestrictionDates",    Parameters.DataImportRestrictionDates);
	AdditionalParameters.Insert("User",                 CurrentUser);
	AdditionalParameters.Insert("SingleSection",           SingleSection);
	AdditionalParameters.Insert("ValueForAllUsers", ValueForAllUsers);
	
	GetCurrentSettings(
		SetClosingDatesInDatabase, IndicationMethodInDatabase, AdditionalParameters);
	
	// User notification
	NotificationText = "";
	If IsAllUsers(CurrentUser) AND IndicationMethodInDatabase = "" Then
		IndicationMethodInDatabase = "SingleDate";
	EndIf;
	
	If PeriodEndClosingDateSettingMethod <> IndicationMethodInDatabase
	   AND SetClosingDatesInDatabase <> "NoPeriodEnd"
	   AND (SetPeriodEndClosingDate = SetClosingDatesInDatabase
	      Or IsAllUsers(CurrentUser) ) Then
		
		ListItem = Items.PeriodEndClosingDateSettingMethod.ChoiceList.FindByValue(IndicationMethodInDatabase);
		If ListItem = Undefined Then
			IndicationMethodInDatabasePresentation = IndicationMethodInDatabase;
		Else
			IndicationMethodInDatabasePresentation = ListItem.Presentation;
		EndIf;
		
		If IndicationMethodInDatabasePresentation <> "" Then
			NotificationText = NotificationText + MessageTextIndicationMethodNotUsed(
				PeriodEndClosingDateSettingMethod,
				IndicationMethodInDatabasePresentation,
				CurrentUser,
				ThisObject);
		EndIf;
	EndIf;
	
	Return NotificationText;
	
EndFunction

&AtServerNoContext
Procedure GetCurrentSettings(SetPeriodEndClosingDate, IndicationMethod, Val Parameters)
	
	SetPeriodEndClosingDate = CurrentSettingOfPeriodEndClosingDate(Parameters.DataImportRestrictionDates);
	If SetPeriodEndClosingDate = "NoPeriodEnd" Then
		Return;
	EndIf;
	
	IndicationMethod = CurrentIndicationMethodOfPeriodEndClosingDate(
		Parameters.User,
		Parameters.SingleSection,
		Parameters.ValueForAllUsers,
		Parameters.BegOfDay);
	
EndProcedure

&AtServerNoContext
Function CurrentSettingOfPeriodEndClosingDate(DataImportRestrictionDates)
	
	BeginTransaction();
	Try
		Query = New Query;
		Query.SetParameter("DataImportRestrictionDates", DataImportRestrictionDates);
		Query.Text =
		"SELECT TOP 1
		|	TRUE AS HasProhibitions
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	(PeriodClosingDates.User = UNDEFINED
		|			OR CASE
		|				WHEN VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.Users)
		|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.UserGroups)
		|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsers)
		|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsersGroups)
		|						OR PeriodClosingDates.User = VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllUsers)
		|					THEN &DataImportRestrictionDates = FALSE
		|				ELSE &DataImportRestrictionDates = TRUE
		|			END)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	TRUE AS ByUsers
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	(PeriodClosingDates.User = UNDEFINED
		|			OR CASE
		|				WHEN VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.Users)
		|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.UserGroups)
		|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsers)
		|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsersGroups)
		|					THEN &DataImportRestrictionDates = FALSE
		|				ELSE &DataImportRestrictionDates = TRUE
		|			END)
		|	AND VALUETYPE(PeriodClosingDates.User) <> TYPE(Enum.PeriodClosingDatesPurposeTypes)";
		
		QueryResults = Query.ExecuteBatch();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If QueryResults[0].IsEmpty() Then
		CurrentSettingOfClosingDates = "NoPeriodEnd";
		
	ElsIf QueryResults[1].IsEmpty() Then
		CurrentSettingOfClosingDates = "ForAllUsers";
	Else
		CurrentSettingOfClosingDates = "ByUsers";
	EndIf;
	
	Return CurrentSettingOfClosingDates;
	
EndFunction

&AtServer
Procedure SetVisibility()
	
	ChangeVisibility(Items.ClosingDateSetting, SetPeriodEndClosingDate <> "NoPeriodEnd");
	If Parameters.DataImportRestrictionDates Then
		If SetPeriodEndClosingDate = "NoPeriodEnd" Then
			ExtendedTooltip = NStr("ru = 'Разрешена загрузка из других программ любых данных прошлых периодов.'; en = 'It is allowed to import any data of the previous periods from other applications.'; pl = 'Pobieranie z innych programów jakichkolwiek danych z poprzednich okresów jest dozwolone.';es_ES = 'Está permitido descargar de otros programas cualesquier datos de los períodos anteriores.';es_CO = 'Está permitido descargar de otros programas cualesquier datos de los períodos anteriores.';tr = 'Geçmiş dönemlerin herhangi bir verisinin diğer programlardan içe aktarılmasına izin verilir.';it = 'L''importazione di dati dei periodi precedenti da altre applicazioni è consentita.';de = 'Erlaubt das Herunterladen von Daten aus früheren Zeiträumen aus anderen Programmen.'");
		ElsIf SetPeriodEndClosingDate = "ForAllUsers" Then
			ExtendedTooltip = NStr("ru = 'Даты запрета загрузки данных из других программ действуют одинаково для всех пользователей.'; en = 'Data import restriction dates from other applications are applied the same way for all users.'; pl = 'Daty zakazu pobierania danych od innych programów są takie same dla wszystkich użytkowników.';es_ES = 'La fecha de restricción de descargar los datos de otros programas funcionan del mismo modo para todos los usuarios.';es_CO = 'La fecha de restricción de descargar los datos de otros programas funcionan del mismo modo para todos los usuarios.';tr = 'Diğer programlardan veri indirmeyi yasaklayan tarihler tüm kullanıcılar için aynı şekilde çalışır.';it = 'Le date di divieto del download dei dati da altri programmi operano allo stesso modo per tutti gli utenti.';de = 'Daten, die das Herunterladen von Daten aus anderen Programmen verbieten, sind für alle Benutzer gleich.'");
		Else
			ExtendedTooltip = NStr("ru = 'Персональная настройка дат запрета загрузки данных прошлых периодов из других программ для выбранных пользователей.'; en = 'Custom setup of data import restriction dates of previous periods from other applications for selected users.'; pl = 'Personalne ustawienia dat zakazu pobierania danych z poprzednich okresów z innych programów dla wybranych użytkowników.';es_ES = 'El ajuste personal de las fechas de restricción de descargar los datos de los períodos anteriores de otros programas para los usuarios seleccionados.';es_CO = 'El ajuste personal de las fechas de restricción de descargar los datos de los períodos anteriores de otros programas para los usuarios seleccionados.';tr = 'Seçilen kullanıcılar için diğer programlardan geçmiş dönemlerin verilerini indirmeyi yasaklayan tarihlerin kişisel olarak yapılandırılması.';it = 'Impostazione personale delle date del divieto di download di dati di periodi precedenti da altri programmi per utenti selezionati.';de = 'Personalisieren Sie das Datum des Verbots des Herunterladens von Daten früherer Zeiträume aus anderen Programmen für ausgewählte Benutzer.'");
		EndIf;
	Else
		If SetPeriodEndClosingDate = "NoPeriodEnd" Then
			ExtendedTooltip = NStr("ru = 'Разрешены ввод и редактирование любых данных прошлых периодов.'; en = 'It is allowed to enter and edit any data of the previous periods.'; pl = 'Pozwolenie na wprowadzanie i edytowanie dowolnych danych z poprzednich okresów.';es_ES = 'La introducción y la edición de los datos de los períodos anteriores están permitidas.';es_CO = 'La introducción y la edición de los datos de los períodos anteriores están permitidas.';tr = 'Geçmiş dönemlere ait herhangi verilerin girişi ve düzenlenmesi yapılabilir.';it = 'È possibile inserire e modificare qualsiasi dato dei periodi precedenti.';de = 'Alle Daten früherer Zeiträume können eingegeben und bearbeitet werden.'");
		ElsIf SetPeriodEndClosingDate = "ForAllUsers" Then
			ExtendedTooltip = NStr("ru = 'Даты запрета ввода и редактирования данных прошлых периодов действуют одинаково для всех пользователей.'; en = 'Dates of restriction of entering and editing previous period data are applied the same way for all users.'; pl = 'Daty zakazu wprowadzania i edycji danych z poprzednich okresów są takie same dla wszystkich użytkowników.';es_ES = 'La fecha de restricción de introducción y edición de los datos de los períodos anteriores funcionan del mismo modo para todos los usuarios.';es_CO = 'La fecha de restricción de introducción y edición de los datos de los períodos anteriores funcionan del mismo modo para todos los usuarios.';tr = 'Geçmiş dönemlerin veri girişini ve düzenlenmesini yasaklayan tarihler tüm kullanıcılar için aynı şekilde çalışır.';it = 'Le date di divieto di inserimento e modifica di dati precedenti sono le stesse per tutti gli utenti.';de = 'Die Termine für das Verbot der Eingabe und Bearbeitung von Daten früherer Zeiträume sind für alle Benutzer gleich.'");
		Else
			ExtendedTooltip = NStr("ru = 'Персональная настройка дат запрета ввода и редактирования данных прошлых периодов для выбранных пользователей.'; en = 'Custom setup of period-end closing dates of previous periods for the selected users.'; pl = 'Personalne ustawienia dat wprowadzania i edycji danych z poprzednich okresów dla wybranych użytkowników.';es_ES = 'El ajuste personal de las fechas de restricción de introducción y edición de los datos de los períodos anteriores para los usuarios seleccionados.';es_CO = 'El ajuste personal de las fechas de restricción de introducción y edición de los datos de los períodos anteriores para los usuarios seleccionados.';tr = 'Seçilen kullanıcılar için geçmiş dönemlerin veri girişini ve düzenlemesini yasaklayan tarihleri kişisel olarak yapılandırılması.';it = 'Impostazione personale delle date di divieto di inserimento e modifica dei dati dei periodi precedenti per utenti selezionati.';de = 'Persönliche Einstellung von Verbotsdaten der Eingabe und Bearbeitung von Daten früherer Zeiträume für ausgewählte Benutzer.'");
		EndIf;
	EndIf;
	Items.SetClosingDateNote.Title = ExtendedTooltip;
	
	If SetPeriodEndClosingDate = "NoPeriodEnd" Then
		Return;
	EndIf;
	
	If SetPeriodEndClosingDate <> "ForAllUsers" Then
		ChangeVisibility(Items.SetForUsers, True);
		Items.CurrentUserPresentation.ShowTitle = True;
	Else
		ChangeVisibility(Items.SetForUsers, False);
		Items.CurrentUserPresentation.ShowTitle = False;
	EndIf;
	
	If SetPeriodEndClosingDate <> "ByUsers" Then
		Items.UserData.CurrentPage = Items.UserSelectedPage;
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeVisibility(Item, Visibility)
	
	If Item.Visible <> Visibility Then
		Item.Visible = Visibility;
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeSettingOfPeriodEndClosingDate(Val SelectedValue, Val DeleteExtra)
	
	If DeleteExtra Then
		
		BeginTransaction();
		Try
			Query = New Query;
			Query.SetParameter("DataImportRestrictionDates",
				Parameters.DataImportRestrictionDates);
			
			If SelectedValue = "NoPeriodEnd" Then
				Query.SetParameter("KeepForAllUsers", False);
				
			ElsIf SelectedValue = "ForAllUsers" Then
				Query.SetParameter("KeepForAllUsers", True);
			Else
				Query.SetParameter("DataImportRestrictionDates", Undefined);
			EndIf;
			
			Query.Text =
			"SELECT
			|	PeriodClosingDates.Section,
			|	PeriodClosingDates.Object,
			|	PeriodClosingDates.User
			|FROM
			|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
			|WHERE
			|	(PeriodClosingDates.User = UNDEFINED
			|			OR CASE
			|				WHEN VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.Users)
			|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.UserGroups)
			|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsers)
			|						OR VALUETYPE(PeriodClosingDates.User) = TYPE(Catalog.ExternalUsersGroups)
			|						OR PeriodClosingDates.User = VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllUsers)
			|					THEN &DataImportRestrictionDates = FALSE
			|				ELSE &DataImportRestrictionDates = TRUE
			|			END)
			|	AND CASE
			|			WHEN VALUETYPE(PeriodClosingDates.User) = TYPE(Enum.PeriodClosingDatesPurposeTypes)
			|				THEN &KeepForAllUsers = FALSE
			|			ELSE TRUE
			|		END";
			RecordKeysValues = Query.Execute().Unload();
			
			// Locking records being deleted.
			For Each RecordKeyValues In RecordKeysValues Do
				LockUserRecordAtServer(LocksAddress,
					RecordKeyValues.Section,
					RecordKeyValues.Object,
					RecordKeyValues.User);
			EndDo;
			
			// Deleting locked records.
			For Each RecordKeyValues In RecordKeysValues Do
				DeleteUserRecord(LocksAddress,
					RecordKeyValues.Section,
					RecordKeyValues.Object,
					RecordKeyValues.User);
			EndDo;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			UnlockAllRecordsAtServer(LocksAddress);
			Raise;
		EndTry;
		UnlockAllRecordsAtServer(LocksAddress);
	EndIf;
	
	ReadUsers();
	ReadUserData(ThisObject);
	
	SetVisibility();
	
EndProcedure

&AtServerNoContext
Function CurrentIndicationMethodOfPeriodEndClosingDate(Val User, Val SingleSection, Val ValueForAllUsers, Val BegOfDay, Data = Undefined)
	
	BeginTransaction();
	Try
		Query = New Query;
		Query.SetParameter("User",                 User);
		Query.SetParameter("SingleSection",           SingleSection);
		Query.SetParameter("EmptyDate",                   '00010101');
		Query.SetParameter("ValueForAllUsers", ValueForAllUsers);
		Query.Text =
		"SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	NOT(&User <> PeriodClosingDates.User
		|				AND &User <> ""*"")
		|	AND NOT(PeriodClosingDates.Section = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
		|				AND PeriodClosingDates.Object = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	NOT(&User <> PeriodClosingDates.User
		|				AND &User <> ""*"")
		|	AND PeriodClosingDates.Section <> VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
		|	AND PeriodClosingDates.Object <> VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
		|	AND PeriodClosingDates.Object <> PeriodClosingDates.Section
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	TRUE AS TrueValue
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	NOT(&User <> PeriodClosingDates.User
		|				AND &User <> ""*"")
		|	AND PeriodClosingDates.Section <> VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
		|	AND PeriodClosingDates.Section <> &SingleSection
		|
		|UNION ALL
		|
		|SELECT TOP 1
		|	TRUE
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	NOT(&User <> PeriodClosingDates.User
		|				AND &User <> ""*"")
		|	AND PeriodClosingDates.Section <> VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
		|	AND PeriodClosingDates.Section = PeriodClosingDates.Object";
		
		QueryResults = Query.ExecuteBatch();
		
		CurrentIndicationMethodOfPeriodEndClosingDate = "";
		
		Query.Text =
		"SELECT
		|	PeriodClosingDates.PeriodEndClosingDate,
		|	PeriodClosingDates.PeriodEndClosingDateDetails
		|FROM
		|	InformationRegister.PeriodClosingDates AS PeriodClosingDates
		|WHERE
		|	PeriodClosingDates.User = &User
		|	AND PeriodClosingDates.Section = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
		|	AND PeriodClosingDates.Object = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)";
		Selection = Query.Execute().Select();
		CommonDateRead = Selection.Next();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Data = Undefined Then
		Data = New Structure;
		Data.Insert("PeriodEndClosingDateDetails", "");
		Data.Insert("PeriodEndClosingDate", '00010101');
		Data.Insert("PermissionDaysCount", 0);
		Data.Insert("RecordExists", CommonDateRead);
	EndIf;
	
	If CommonDateRead Then
		Data.PeriodEndClosingDate = PeriodClosingDatesInternal.PeriodEndClosingDateByDetails(
			Selection.PeriodEndClosingDateDetails, Selection.PeriodEndClosingDate, BegOfDay);
		FillByInternalDetailsOfPeriodEndClosingDate(Data, Selection.PeriodEndClosingDateDetails);
	EndIf;
	
	If QueryResults[0].IsEmpty() Then
		// Absent by objects and sections, when it is blank.
		CurrentIndicationMethodOfPeriodEndClosingDate = ?(CommonDateRead, "SingleDate", "");
		
	ElsIf Not QueryResults[1].IsEmpty() Then
		// Exists by objects, when it is not blank.
		
		If QueryResults[2].IsEmpty()
		   AND ValueIsFilled(SingleSection) Then
			// Only by SingleSection (without section dates), when it is blank.
			CurrentIndicationMethodOfPeriodEndClosingDate = "ByObjects";
		Else
			CurrentIndicationMethodOfPeriodEndClosingDate = "BySectionsAndObjects";
		EndIf;
	Else
		CurrentIndicationMethodOfPeriodEndClosingDate = "BySections";
	EndIf;
	
	Return CurrentIndicationMethodOfPeriodEndClosingDate;
	
EndFunction

&AtServer
Procedure DeleteExtraOnChangePeriodEndClosingDateIndicationMethod(Val SelectedValue, Val CurrentUser, Val SetPeriodEndClosingDate)
	
	RecordSet = InformationRegisters.PeriodClosingDates.CreateRecordSet();
	RecordSet.Filter.User.Set(CurrentUser);
	RecordSet.Read();
	Index = RecordSet.Count()-1;
	While Index >= 0 Do
		Record = RecordSet[Index];
		If  SelectedValue = "SingleDate" Then
			If Not (  Record.Section = SectionEmptyRef
					 AND Record.Object = SectionEmptyRef ) Then
				RecordSet.Delete(Record);
			EndIf;
		ElsIf SelectedValue = "BySections" Then
			If Record.Section <> Record.Object
			 Or Record.Section = SectionEmptyRef
			   AND Record.Object = SectionEmptyRef Then
				RecordSet.Delete(Record);
			EndIf;
		ElsIf SelectedValue = "ByObjects" Then
			If Record.Section = Record.Object
			   AND Record.Section <> SectionEmptyRef
			   AND Record.Object <> SectionEmptyRef Then
				RecordSet.Delete(Record);
			EndIf;
		EndIf;
		Index = Index-1;
	EndDo;
	RecordSet.Write();
	
	ReadUserData(ThisObject);
	
EndProcedure

&AtClient
Procedure EditPeriodEndClosingDateInForm()
	
	SelectedRows = Items.ClosingDates.SelectedRows;
	// Canceling selection of section rows with objects.
	Index = SelectedRows.Count()-1;
	UpdateSelection = False;
	While Index >= 0 Do
		Row = ClosingDates.FindByID(SelectedRows[Index]);
		If Not ValueIsFilled(Row.Presentation) Then
			SelectedRows.Delete(Index);
			UpdateSelection = True;
		EndIf;
		Index = Index - 1;
	EndDo;
	
	If SelectedRows.Count() = 0 Then
		ShowMessageBox(, NStr("ru ='Выделенные строки не заполнены.'; en = 'The selected lines are not filled in.'; pl = 'Zaznaczone wiersze nie są wypełnione.';es_ES = 'Las líneas seleccionadas no están rellenadas.';es_CO = 'Las líneas seleccionadas no están rellenadas.';tr = 'Seçilen satırlar doldurulmadı.';it = 'Le linee selezionate non sono compilate.';de = 'Die ausgewählten Zeilen sind nicht ausgefüllt.'"));
		Return;
	EndIf;
	
	If UpdateSelection Then
		Items.ClosingDates.Refresh();
		ShowMessageBox(
			New NotifyDescription("EditPeriodEndClosingDateInFormCompletion", ThisObject, SelectedRows),
			NStr("ru = 'Снято выделение с незаполненных строк.'; en = 'Unfilled lines are unchecked.'; pl = 'Zaznaczenie niewypełnionych wierszy zostało usunięte.';es_ES = 'Filas no rellenadas están sin revisar.';es_CO = 'Filas no rellenadas están sin revisar.';tr = 'Doldurulmamış satırlar işaretlenmemiş.';it = 'Selezione di righe vuote rimossa.';de = 'Unausgefüllte Zeilen sind nicht markiert.'"));
	Else
		EditPeriodEndClosingDateInFormCompletion(SelectedRows)
	EndIf;
	
EndProcedure

&AtClient
Procedure EditPeriodEndClosingDateInFormCompletion(SelectedRows) Export
	
	// Locking records of the selected rows.
	For Each SelectedRow In SelectedRows Do
		CurrentData = ClosingDates.FindByID(SelectedRow);
		
		ReadProperties = LockUserRecordAtServer(LocksAddress,
			CurrentSection(CurrentData), CurrentData.Object, CurrentUser);
		
		UpdateReadPropertiesValues(
			CurrentData, ReadProperties, Items.Users.CurrentData);
	EndDo;
	
	// Changing description of a period-end closing date.
	FormParameters = New Structure;
	If SetPeriodEndClosingDate = "ByUsers" Then
		FormParameters.Insert("UserPresentation",
			Items.Users.CurrentData.Presentation);
	Else
		FormParameters.Insert("UserPresentation",
			PresentationTextForAllUsers(ThisObject));
	EndIf;
	
	If SelectedRows.Count() = 1 Then
		If PeriodEndClosingDateSettingMethod = "ByObjects" Then
			
			If Items.ClosingDates.CurrentData.IsSection Then
				FormParameters.Insert("SectionPresentation",
					Items.ClosingDates.CurrentData.Presentation);
				FormParameters.Insert("Object", "");
			Else
				FormParameters.Insert("SectionPresentation", "");
				FormParameters.Insert("Object", Items.ClosingDates.CurrentData.Object);
			EndIf;
		Else
			If Items.ClosingDates.CurrentData.IsSection Then
				FormParameters.Insert("SectionPresentation",
					Items.ClosingDates.CurrentData.Presentation);
			Else
				FormParameters.Insert("SectionPresentation",
					Items.ClosingDates.CurrentData.GetParent().Presentation);
				
				FormParameters.Insert("ObjectPresentation", Items.ClosingDates.CurrentData.Object);
			EndIf;
		EndIf;
	Else
		FormParameters.Insert("SectionPresentation", "");
		FormParameters.Insert("Object", 
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Выбранные строки (%1)'; en = 'Selected lines (%1)'; pl = 'Wybrane wierszy (%1)';es_ES = 'Líneas seleccionadas (%1)';es_CO = 'Líneas seleccionadas (%1)';tr = 'Seçilmiş satırlar (%1)';it = 'Righe selezionate (%1)';de = 'Ausgewählte Zeilen (%1)'"), SelectedRows.Count()));
	EndIf;
	FormParameters.Insert("PeriodEndClosingDateDetails", Items.ClosingDates.CurrentData.PeriodEndClosingDateDetails);
	FormParameters.Insert("PermissionDaysCount", Items.ClosingDates.CurrentData.PermissionDaysCount);
	FormParameters.Insert("PeriodEndClosingDate", Items.ClosingDates.CurrentData.PeriodEndClosingDate);
	
	OpenForm("InformationRegister.PeriodClosingDates.Form.PeriodEndClosingDateEdit",
		FormParameters, ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Function DetailsPresentationOfPeriodEndClosingDate(Val Data)
	
	Presentation = PeriodClosingDatesInternalClientServer.ClosingDatesDetails()[Data.PeriodEndClosingDateDetails];
	If Data.PermissionDaysCount > 0 Then
		Presentation = Presentation + " (" + Format(Data.PermissionDaysCount, "NG=") + ")";
	EndIf;
	Return Presentation;
	
EndFunction

&AtClientAtServerNoContext
Function InternalPeriodEndClosingDate(Data)
	
	If ValueIsFilled(Data.PeriodEndClosingDateDetails)
	   AND Data.PeriodEndClosingDateDetails <> "CustomDate" Then
		
		Return '00020202'; // The relative period-end closing date.
	EndIf;
	
	Return Data.PeriodEndClosingDate;
	
EndFunction

&AtClientAtServerNoContext
Function InternalDetailsOfPeriodEndClosingDate(Val Data)
	
	InternalDetails = "";
	If Data.PeriodEndClosingDateDetails <> "CustomDate" Then
		InternalDetails = TrimAll(
			Data.PeriodEndClosingDateDetails + Chars.LF
				+ Format(Data.PermissionDaysCount, "NG=0"));
	EndIf;
	
	Return InternalDetails;
	
EndFunction

&AtClientAtServerNoContext
Procedure FillByInternalDetailsOfPeriodEndClosingDate(Val Data, Val InternalDetails)
	
	Data.PeriodEndClosingDateDetails = "CustomDate";
	Data.PermissionDaysCount = 0;
	
	If ValueIsFilled(InternalDetails) Then
		PeriodEndClosingDateDetails = StrGetLine(InternalDetails, 1);
		PermissionDaysCount = StrGetLine(InternalDetails, 2);
		If PeriodClosingDatesInternalClientServer.ClosingDatesDetails()[PeriodEndClosingDateDetails] = Undefined Then
			Data.PeriodEndClosingDate = '00030303'; // Unknown format.
		Else
			Data.PeriodEndClosingDateDetails = PeriodEndClosingDateDetails;
			If ValueIsFilled(PermissionDaysCount) Then
				TypeDescriptionNumber = New TypeDescription("Number",,,
					New NumberQualifiers(2, 0, AllowedSign.Nonnegative));
				Data.PermissionDaysCount = TypeDescriptionNumber.AdjustValue(PermissionDaysCount);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function IsAllUsers(User)
	
	Return TypeOf(User) = Type("EnumRef.PeriodClosingDatesPurposeTypes");
	
EndFunction

&AtClientAtServerNoContext
Function PeriodEndClosingDateSet(Data, User, BeforeWrite = False)
	
	If Not BeforeWrite Then
		Return Data.RecordExists;
	EndIf;
	
	If Data.Object <> Data.Section AND Not ValueIsFilled(Data.Object) Then
		Return False;
	EndIf;
	
	Return Data.PeriodEndClosingDateDetails <> "";
	
EndFunction

&AtServerNoContext
Procedure LockAndWriteBlankDates(LocksAddress, Section, Object, User, Comment)
	
	If TypeOf(Object) = Type("Array") Then
		ObjectsForAdding = Object;
	Else
		ObjectsForAdding = New Array;
		ObjectsForAdding.Add(Object);
	EndIf;
	
	For Each CurrentObject In ObjectsForAdding Do
		LockUserRecordAtServer(LocksAddress,
			Section, CurrentObject, User);
	EndDo;
	
	For Each CurrentObject In ObjectsForAdding Do
		RecordPeriodEndClosingDateWithDetails(
			Section,
			CurrentObject,
			User,
			'00010101',
			"",
			Comment);
	EndDo;
	
	UnlockAllRecordsAtServer(LocksAddress);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetCommandBarOfClosingDates(Form)
	
	Items = Form.Items;
	
	If IsAllUsers(Form.CurrentUser) Then
		If Form.PeriodEndClosingDateSettingMethod = "BySections" Then
			// ClosingDatesWithoutSectionsSelectionWithoutObjectsSelection
			SetProperty(Items.ClosingDatesPick.Visible, False);
			SetProperty(Items.ClosingDatesAdd.Visible,  False);
			SetProperty(Items.PeriodEndClosingDatesContextMenuAdd.Visible, False);
		Else
			// ClosingDatesWithoutSectionsSelectionWithObjectsSelection
			SetProperty(Items.ClosingDatesPick.Visible, True);
			SetProperty(Items.ClosingDatesAdd.Visible,  True);
			SetProperty(Items.PeriodEndClosingDatesContextMenuAdd.Visible, True);
		EndIf;
	Else
		If Form.PeriodEndClosingDateSettingMethod = "BySections" Then
			// ClosingDatesWithSectionsSelectionWithoutObjectsSelection
			SetProperty(Items.ClosingDatesPick.Visible, False);
			SetProperty(Items.ClosingDatesAdd.Visible,  False);
			SetProperty(Items.PeriodEndClosingDatesContextMenuAdd.Visible, False);
			
		ElsIf Form.PeriodEndClosingDateSettingMethod = "ByObjects" Then
			// ClosingDatesWithCommonDateSelectionWithObjectsSelection
			SetProperty(Items.ClosingDatesPick.Visible, True);
			SetProperty(Items.ClosingDatesAdd.Visible,  True);
			SetProperty(Items.PeriodEndClosingDatesContextMenuAdd.Visible, True);
		Else
			// ClosingDatesWithSectionsSelectionWithObjectsSelection
			SetProperty(Items.ClosingDatesPick.Visible, True);
			SetProperty(Items.ClosingDatesAdd.Visible,  True);
			SetProperty(Items.PeriodEndClosingDatesContextMenuAdd.Visible, True);
		EndIf;
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetProperty(Property, Value)
	If Property <> Value Then
		Property = Value;
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Function CurrentUserComment(Form)
	
	If Form.SetPeriodEndClosingDate = "ByUsers" Then
		Comment = Form.Items.Users.CurrentData.Comment;
	Else
		Comment = CommentTextForAllUsers();
	EndIf;
	
	Return Comment;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary functions of user interface lines.

&AtClientAtServerNoContext
Function PresentationTextForAllUsers(Form)
	
	Return "<" + Form.ValueForAllUsers + ">";
	
EndFunction

&AtClientAtServerNoContext
Function UserPresentationText(Form, User)
	
	If Form.Parameters.DataImportRestrictionDates Then
		For Each ListValue In Form.UserTypesList Do
			If TypeOf(ListValue.Value) = TypeOf(User) Then
				If ValueIsFilled(User) Then
					Return ListValue.Presentation + ": " + String(User);
				Else
					Return ListValue.Presentation + ": " + NStr("ru = '<Все информационные базы>'; en = '<All infobases>'; pl = '<Wszystkie bazy informacyjne>';es_ES = '<Todas infobases>';es_CO = '<All infobases>';tr = '<Tüm bilgi tabanları>';it = '<Tutti gli infobase>';de = 'Alle Datenbanken'");
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	If ValueIsFilled(User) Then
		Return String(User);
	EndIf;
	
	Return String(TypeOf(User));
	
EndFunction

&AtClientAtServerNoContext
Function CommentTextForAllUsers()
	
	Return "(" + NStr("ru = 'По умолчанию'; en = 'Default'; pl = 'Domyślnie';es_ES = 'Por defecto';es_CO = 'Por defecto';tr = 'Varsayılan';it = 'Predefinito';de = 'Standard'") + ")";
	
EndFunction

&AtClientAtServerNoContext
Function CommonDatePresentationText()
	
	Return "<" + NStr("ru = 'Общая дата для всех разделов'; en = 'Common date for all sections'; pl = 'Łączna data dla wszystkich działów';es_ES = 'Fecha común para todas las secciones';es_CO = 'Fecha común para todas las secciones';tr = 'Tüm bölümler için ortak veri';it = 'Data comune per tutte le sezioni';de = 'Gesamtdatum für alle Abschnitte'") + ">";
	
EndFunction

&AtClientAtServerNoContext
Function MessageTextIndicationMethodNotUsed(IndicationMethodInForm, IndicationMethodInDatabase, CurrentUser, Form)
	
	If IndicationMethodInForm = "BySections" Or IndicationMethodInForm = "BySectionsAndObjects" Then
		If IsAllUsers(CurrentUser) Then
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ни для одного раздела не были введены даты запрета, 
					|поэтому для всех пользователей будет действовать более простая настройка ""%1"".'; 
					|en = 'Period-end closing dates are not entered for any section, 
					|a simpler setting ""%1"" will be applied for all users.'; 
					|pl = 'Do żadnej sekcji nie zostały wprowadzone daty zakazu, 
					|więc dla wszystkich użytkowników będzie działać bardziej proste ustawienie ""%1"".';
					|es_ES = 'No están introducidas las fechas de restricción para ninguna sección, 
					|por eso para todos los usuarios funcionará el ajuste más simple ""%1"".';
					|es_CO = 'No están introducidas las fechas de restricción para ninguna sección, 
					|por eso para todos los usuarios funcionará el ajuste más simple ""%1"".';
					|tr = 'Hiçbir bölüm için dönem sonu kapanış tarihi girilmedi, 
					|tüm kullanıcılar için daha basit bir ayar olan ""%1"" uygulanacak.';
					|it = 'Le date di chiusura di fine periodo non sono inserite per nessuna sezione, 
					|verrà applicata l''impostazione più semplice ""%1"" per tutti gli utenti.';
					|de = 'Für keinen der Abschnitte wurden Verbotsdaten eingegeben,
					|so dass alle Benutzer eine einfachere Einstellung ""%1"" haben.'"),
				IndicationMethodInDatabase);
		Else
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ни для одного раздела не были введены даты запрета, 
					|поэтому для ""%1"" будет действовать более простая настройка ""%2"".'; 
					|en = 'Period-end closing dates are not entered for any section, 
					|a simpler setting ""%2"" will be applied for ""%1"".'; 
					|pl = 'Do żadnej sekcji nie zostały wprowadzone daty zakazu, 
					|więc dla ""%1"" będzie działać bardziej proste ustawienie ""%2"".';
					|es_ES = 'No están introducidas las fechas de restricción para ninguna sección, 
					|por eso para ""%1"" funcionará el ajuste más simple ""%2"".';
					|es_CO = 'No están introducidas las fechas de restricción para ninguna sección, 
					|por eso para ""%1"" funcionará el ajuste más simple ""%2"".';
					|tr = 'Hiçbir bölüm için dönem sonu kapanış tarihi girilmedi, 
					|""%1"" için daha basit bir ayar olan ""%2"" uygulanacak.';
					|it = 'Le date di chiusura di fine periodo non sono inserite per nessuna sezione, 
					|verrà applicata l''impostazione più semplice ""%2"" per ""%1"".';
					|de = 'Für keinen der Abschnitte wurden Verbotsdaten eingegeben,
					|so dass der ""%1"" eine einfachere Einstellung für ""%2"" hat.'"),
				CurrentUser, IndicationMethodInDatabase);
		EndIf;
	Else // ByObjects
		If IsAllUsers(CurrentUser) Then
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ни для одного объекта не были введены даты запрета, 
					|поэтому для всех пользователей будет действовать более простая настройка ""%1"".'; 
					|en = 'Period-end closing dates are not entered for any object, 
					|a simpler setting ""%1"" will be applied for all users.'; 
					|pl = 'Do żadnego obiektu nie zostały wprowadzone daty zakazu, 
					|więc dla wszystkich użytkowników będzie działać bardziej proste ustawienie ""%1"".';
					|es_ES = 'No están introducidas las fechas de restricción para ningún objeto, 
					|por eso para todos los usuarios funcionará el ajuste más simple ""%1"".';
					|es_CO = 'No están introducidas las fechas de restricción para ningún objeto, 
					|por eso para todos los usuarios funcionará el ajuste más simple ""%1"".';
					|tr = 'Hiçbir nesne için dönem sonu kapanış tarihi girilmedi, 
					|tüm kullanıcılar için daha basit bir ayar olan ""%1"" uygulanacak.';
					|it = 'Le date di chiusura di fine periodo non sono inserite per nessun oggetto, 
					|verrà applicata l''impostazione più semplice ""%1"" per tutti gli utenti.';
					|de = 'Es wurden keine Verbotsdaten für ein Objekt eingegeben,
					|so dass alle Benutzer eine einfachere Einstellung ""%1"" haben.'"),
				IndicationMethodInDatabase);
		Else
			Return StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ни для одного объекта не были введены даты запрета, 
					|поэтому для ""%1"" будет действовать более простая настройка ""%2"".'; 
					|en = 'Period-end closing dates are not entered for any object, 
					|a simpler setting ""%2"" will be valid for ""%1"".'; 
					|pl = 'Do żadnej obiektu nie zostały wprowadzone daty zakazu, 
					|więc dla ""%1"" będzie działać bardziej proste ustawienie ""%2"".';
					|es_ES = 'No están introducidas las fechas de restricción para ningún objeto, 
					|por eso para ""%1"" funcionará el ajuste más simple ""%2"".';
					|es_CO = 'No están introducidas las fechas de restricción para ningún objeto, 
					|por eso para ""%1"" funcionará el ajuste más simple ""%2"".';
					|tr = 'Hiçbir nesne için dönem sonu kapanış tarihi girilmedi, 
					|""%1"" için daha basit bir ayar olan ""%2"" uygulanacak.';
					|it = 'Le date di chiusura di fine periodo non sono inserite per nessun oggetto, 
					|sarà valida l''impostazione più semplice ""%2"" per ""%1"".';
					|de = 'Es wurden keine Verbotsdaten für ein Objekt eingegeben,
					|so dass eine einfachere Einstellung von ""%2"" für ""%1"" funktioniert.'"),
				CurrentUser, IndicationMethodInDatabase);
		EndIf;
	EndIf;
	
EndFunction

&AtClient
Function MessageTextInSelectedSectionClosingDatesForObjectsNotSet(Section)
	
	Return ?(Section <> SectionEmptyRef, 
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'В разделе ""%1"" не предусмотрена установка дат запрета для отдельных объектов.'; en = 'Period-end closing date setting is not available for separate objects in the ""%1"" section.'; pl = 'W sekcji ""%1"" nie jest przewidziane ustawienie dat zakazu dla poszczególnych obiektów.';es_ES = 'En la sección ""%1"" no está prevista la instalación de las fechas de restricción para algunos objetos.';es_CO = 'En la sección ""%1"" no está prevista la instalación de las fechas de restricción para algunos objetos.';tr = 'Dönem sonu kapanış tarihi ayarı ""%1"" bölümündeki ayrı nesneler için kullanılamaz.';it = 'Nella sezione ""%1"" non è prevista l''impostazione delle date di divieto per singoli oggetti.';de = 'Der Abschnitt ""%1"" enthält nicht die Einstellung von Verbotsdaten für einzelne Objekte.'"), Section),
		NStr("ru = 'Для установки дат запрета по отдельным объектам выберите один из разделов ниже и нажмите ""Подобрать"".'; en = 'To set a period-end closing date for separate objects, choose one of the sections below, and then click Select.'; pl = 'W celu ustawienia dat zakazu według obiektów pojedynczych wybierz jedną z sekcji niżej i kliknij ""Dopasuj"".';es_ES = 'Para instalar las fechas de restricción por unos objetos seleccione una de las secciones abajo y pulse ""Escoger"".';es_CO = 'Para instalar las fechas de restricción por unos objetos seleccione una de las secciones abajo y pulse ""Escoger"".';tr = 'Ayrı nesneler için dönem sonu kapanış tarihi girmek için, aşağıdaki bölümlerden birini seçin ve ardından Seç''e tıklayın.';it = 'Per l''impostazione delle date di divieto per singoli oggetti, selezionare una delle sezioni in basso e premere ""Seleziona"".';de = 'Um die Verbotsdaten für einzelne Objekte festzulegen, wählen Sie einen der folgenden Abschnitte aus und klicken Sie auf ""Anpassen"".'"));
	
EndFunction

&AtClientAtServerNoContext
Function HeaderTextDataTypeSelection()
	
	Return NStr("ru = 'Выбор типа данных'; en = 'Select data type'; pl = 'Wybierz typ danych';es_ES = 'Seleccionar el tipo de datos';es_CO = 'Seleccionar el tipo de datos';tr = 'Veri türünü seçin';it = 'Selezione del tipo di dati';de = 'Wählen Sie den Datentyp aus'");
	
EndFunction

#EndRegion
