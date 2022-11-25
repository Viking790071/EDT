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
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations")
	   AND Users.IsFullUser() Then
		
		// Visibility settings at startup.
		Items.ExtractTextAutomaticallyGroup.Visible =
			  Users.IsFullUser(, True)
			AND Not Common.DataSeparationEnabled()
			AND NOT CommonClientServer.IsMobileClient();
		
	Else
		Items.ExtractTextAutomaticallyGroup.Visible = False;
	EndIf;
	
	If Items.ExtractTextAutomaticallyGroup.Visible Then
		
		If Common.FileInfobase() Then
			ChoiceList = Items.ExtractFilesTextsAtWindowsServer.ChoiceList;
			ChoiceList[0].Presentation = NStr("ru = 'Все рабочие станции работают под управлением ОС Windows'; en = 'All workstations are running under Windows OS'; pl = 'Wszystkie stacje robocze pracują pod kontrolą SO Windows';es_ES = 'Todas las estaciones de trabajo funcionan bajo el OS Windows';es_CO = 'Todas las estaciones de trabajo funcionan bajo el OS Windows';tr = 'Tüm iş istasyonları Windows işletim sistemi altında çalışır';it = 'Tutte le workstations lavorano sotto sistema operativo Windows';de = 'Alle Workstations laufen unter Windows-Betriebssystem'");
			
			ChoiceList = Items.ExtractFilesTextsAtLinuxServer.ChoiceList;
			ChoiceList[0].Presentation = NStr("ru = 'Одна или несколько рабочих станций работают под управлением ОС Linux'; en = 'One or multiple workstations are running under Linux OS'; pl = 'Jedna lub kilka stacji roboczych pracują pod kontrolą SO Linux';es_ES = 'Una o varias estaciones de trabajo funcionan bajo el OS Linux';es_CO = 'Una o varias estaciones de trabajo funcionan bajo el OS Linux';tr = 'Bir ya da birkaç iş istasyonu Linux OS altında çalışır';it = 'Una o più workstations lavorano con sistema operativo Linux';de = 'Eine oder mehrere Workstations arbeiten mit Linux-Betriebssystem'");
		EndIf;
		
		// Form attributes values.
		ExtractTextFilesOnServer = ConstantsSet.ExtractTextFilesOnServer;
	
		ScheduledJobsInfo = New Structure;
		FillScheduledJobInfo("TextExtraction");
	Else
		AutoTitle = False;
		Title = NStr("ru = 'Управление полнотекстовым поиском'; en = 'Full-text search management'; pl = 'Kierowanie wyszukiwaniem tekstowym';es_ES = 'Gestionar la búsqueda de texto completo';es_CO = 'Gestionar la búsqueda de texto completo';tr = 'Tam metin aramayı yönet';it = 'Gestione ricerca full-text';de = 'Verwalten Sie die Volltextsuche'");
		Items.SectionDetails.Title =
			NStr("ru = 'Включение и отключение полнотекстового поиска, обновление индекса полнотекстового поиска.'; en = 'Enable and disable full-text search, update full-text search index.'; pl = 'Włączanie i wyłączanie wyszukiwania pełnotekstowego, aktualizacja indeksu wyszukiwania pełnotekstowego.';es_ES = 'Activación y desactivación de la búsqueda de texto completo, actualización del índice de la búsqueda de texto completo.';es_CO = 'Activación y desactivación de la búsqueda de texto completo, actualización del índice de la búsqueda de texto completo.';tr = 'Tam metin aramanın etkinleştirilmesi ve devre dışı bırakılması, tam metin arama dizininin güncellenmesi.';it = 'Abilita e disabilita la ricerca full-text, aggiorna gli indici di ricerca full-text.';de = 'Aktivierung und Deaktivierung der Volltextsuche, Aktualisierung des Volltextsuchindex.'");
	EndIf;
	
	// Update items states.
	SetAvailability();
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(
		ThisObject, "ExtractTextAutomaticallyGroup");
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	If Exit Then
		Return;
	EndIf;
	UpdateApplicationInterface();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ExtractFilesTextsAtServerOnChange(Item)
	Attachable_OnChangeAttribute(Item, False);
EndProcedure

&AtClient
Procedure DataToIndexMaxSizeOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure RestrictDataToIndexMaxSizeOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure UpdateIndex(Command)
	UpdateIndexServer();
	ShowUserNotification(NStr("ru = 'Полнотекстовый поиск'; en = 'Full-text search'; pl = 'Wyszukiwanie pełnotekstowe';es_ES = 'Búsqueda de texto completo';es_CO = 'Búsqueda de texto completo';tr = 'Tam metin arama';it = 'Ricerca Full-text';de = 'Volltextsuche'"),, NStr("ru = 'Индекс успешно обновлен'; en = 'Index is successfully updated'; pl = 'Indeks został pomyślnie zaktualizowany';es_ES = 'Índice ha sido actualizado con éxito';es_CO = 'Índice ha sido actualizado con éxito';tr = 'Dizin başarı ile güncellendi';it = 'L''indice è aggiornato con successo';de = 'Index erfolgreich aktualisiert'"));
EndProcedure

&AtClient
Procedure ClearIndex(Command)
	ClearIndexServer();
	ShowUserNotification(NStr("ru = 'Полнотекстовый поиск'; en = 'Full-text search'; pl = 'Wyszukiwanie pełnotekstowe';es_ES = 'Búsqueda de texto completo';es_CO = 'Búsqueda de texto completo';tr = 'Tam metin arama';it = 'Ricerca Full-text';de = 'Volltextsuche'"),, NStr("ru = 'Индекс успешно очищен'; en = 'Index is successfully cleaned up'; pl = 'Indeks został pomyślnie oczyszczony';es_ES = 'Índice ha sido limpiado con éxito';es_CO = 'Índice ha sido limpiado con éxito';tr = 'Dizin başarı ile temizlendi';it = 'L''indice è stato pulito con successo';de = 'Index erfolgreich gereinigt'"));
EndProcedure

&AtClient
Procedure CheckIndex(Command)
	Try
		CheckIndexServer();
	Except
		ErrorMessageText = 
			NStr("ru = 'В настоящее время проверка индекса невозможна, так как выполняется его очистка или обновление.'; en = 'Index check is unavailable now as the index is being updated or cleaned up.'; pl = 'Obecnie weryfikacja indeksu nie jest możliwa, ponieważ wykonuje się jego czyszczenie lub aktualizacja.';es_ES = 'Actualmente es imposible comprobar el índice porque se está limpiando o se está actualizando.';es_CO = 'Actualmente es imposible comprobar el índice porque se está limpiando o se está actualizando.';tr = 'Dizin doğrulama şu anda mümkün değildir, çünkü temizleme veya güncelleme yapılır.';it = 'Il controllo indice non è disponibile adesso dato che l''indice viene aggiornato e pulito.';de = 'Der Index kann derzeit nicht überprüft werden, da er gereinigt oder aktualisiert wird.'");
		CommonClientServer.MessageToUser(ErrorMessageText);
	EndTry;
	
	ShowUserNotification(NStr("ru = 'Полнотекстовый поиск'; en = 'Full-text search'; pl = 'Wyszukiwanie pełnotekstowe';es_ES = 'Búsqueda de texto completo';es_CO = 'Búsqueda de texto completo';tr = 'Tam metin arama';it = 'Ricerca Full-text';de = 'Volltextsuche'"),, NStr("ru = 'Индекс содержит корректные данные'; en = 'Index contains correct data'; pl = 'Indeks zawiera prawidłowe dane';es_ES = 'El índice contiene los datos correctos';es_CO = 'El índice contiene los datos correctos';tr = 'Dizin doğru veri içermektedir';it = 'L''indice contiene dati corretti';de = 'Der Index enthält korrekte Daten'"));
EndProcedure

&AtClient
Procedure EditScheduledJob(Command)
	ScheduledJobsHyperlinkClick("TextExtraction");
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure Attachable_OnChangeAttribute(Item, UpdateInterface = True)
	
	Result = OnChangeAttributeServer(Item.Name);
	
	RefreshReusableValues();
	
	If Result.Property("CannotEnableFullTextSearchMode") Then
		// Display a warning message.
		QuestionText = NStr("ru = 'Для изменения режима полнотекстового поиска требуется завершение сеансов всех пользователей, кроме текущего.'; en = 'To change the full-text search mode, close sessions of all users except for the current one.'; pl = 'Aby zmienić tryb wyszukiwania pełnotekstowego należy zakończyć sesje wszystkich użytkowników, oprócz bieżącego.';es_ES = 'Para cambiar el modo de texto completo se requiere terminar todas las sesiones de todos los usuarios a excepción de la actual.';es_CO = 'Para cambiar el modo de texto completo se requiere terminar todas las sesiones de todos los usuarios a excepción de la actual.';tr = 'Tam metin arama modunu değiştirmek için mevcut kullanıcı dışındaki tüm kullanıcı oturumlarını tamamlamanız gerekir.';it = 'Per modificare la modalità di ricerca full-text, chiudi le sessioni di tutti gli utenti tranne il corrente.';de = 'Um den Volltextsuchmodus zu ändern, müssen alle Benutzer außer dem aktuellen Benutzer abgemeldet werden.'");
		
		Buttons = New ValueList;
		Buttons.Add("ActiveUsers", NStr("ru = 'Активные пользователи'; en = 'Active users'; pl = 'Aktualni użytkownicy';es_ES = 'Usuarios activos';es_CO = 'Usuarios activos';tr = 'Aktif kullanıcılar';it = 'Utenti attivi';de = 'Active Users'"));
		Buttons.Add(DialogReturnCode.Cancel);
		
		Handler = New NotifyDescription("OnChangeAttributeAfterAnswerToQuestion", ThisObject);
		ShowQueryBox(Handler, QuestionText, Buttons, , "ActiveUsers");
		Return;
	EndIf;
	
	If UpdateInterface Then
		RefreshInterface = True;
		AttachIdleHandler("UpdateApplicationInterface", 2, True);
	EndIf;
	
	If Result.ConstantName <> "" Then
		Notify("Write_ConstantsSet", New Structure, Result.ConstantName);
	EndIf;
	
EndProcedure

&AtClient
Procedure ScheduledJobsHyperlinkClick(PredefinedItemName)
	Information = ScheduledJobsInfo[PredefinedItemName];
	If Information.ID = Undefined Then
		Return;
	EndIf;
	Context = New Structure;
	Context.Insert("PredefinedItemName", PredefinedItemName);
	Context.Insert("CheckBoxChanged", False);
	Handler = New NotifyDescription("ScheduledJobsAfterChangeSchedule", ThisObject, Context);
	Dialog = New ScheduledJobDialog(Information.Schedule);
	Dialog.Show(Handler);
EndProcedure

&AtClient
Procedure ScheduledJobsAfterChangeSchedule(Schedule, Context) Export
	If Schedule = Undefined Then
		If Context.CheckBoxChanged Then
			ThisObject[Context.CheckBoxName] = False;
		EndIf;
		Return;
	EndIf;
	
	Changes = New Structure("Schedule", Schedule);
	If Context.CheckBoxChanged Then
		ThisObject[Context.CheckBoxName] = True;
		Changes.Insert("Use", True);
	EndIf;
	ScheduledJobsSave(Context.PredefinedItemName, Changes, True);
EndProcedure

&AtClient
Procedure OnChangeAttributeAfterAnswerToQuestion(Response, ExecutionParameters) Export
	If Response = "ActiveUsers" Then
		StandardSubsystemsClient.OpenActiveUserList();
	EndIf;
EndProcedure

&AtClient
Procedure UpdateApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		CommonClient.RefreshApplicationInterface();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server call

&AtServer
Procedure UpdateIndexServer()
	FullTextSearch.UpdateIndex(False, False);
	SetAvailability("Command.UpdateIndex");
EndProcedure

&AtServer
Procedure ClearIndexServer()
	FullTextSearch.ClearIndex();
	SetAvailability("Command.ClearIndex");
EndProcedure

&AtServer
Procedure CheckIndexServer()
	IndexContainsCorrectData = FullTextSearch.CheckIndex();
	SetAvailability("Command.CheckIndex", True);
EndProcedure

&AtServer
Function OnChangeAttributeServer(ItemName)
	
	DataPathAttribute = Items[ItemName].DataPath;
	
	Result = SaveAttributeValue(DataPathAttribute);
	
	SetAvailability(DataPathAttribute);
	
	If Result.Property("CannotEnableFullTextSearchMode") Then
		Return Result;
	EndIf;
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

&AtServer
Procedure ScheduledJobsSave(PredefinedItemName, Changes, SetVisibilityAvailability)
	Information = ScheduledJobsInfo[PredefinedItemName];
	If Information.ID = Undefined Then
		Return;
	EndIf;
	ScheduledJobsServer.ChangeJob(Information.ID, Changes);
	FillPropertyValues(Information, Changes);
	ScheduledJobsInfo.Insert(PredefinedItemName, Information);
	If SetVisibilityAvailability Then
		SetAvailability("ScheduledJob." + PredefinedItemName);
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Function SaveAttributeValue(DataPathAttribute)
	Result = New Structure("ConstantName", "");
	
	// Save values of attributes not directly related to constants (in ratio one to one).
	If DataPathAttribute = "" Then
		Return Result;
	EndIf;
	
	// Define the constant name.
	ConstantName = "";
	If Lower(Left(DataPathAttribute, 14)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified via ConstantsSet.
		ConstantName = Mid(DataPathAttribute, 15);
	Else
		// Define the name and record the attribute value in the constant from the ConstantsSet.
		// It is used for those form attributes that are directly related to constants (in ratio one to one).
		If DataPathAttribute = "ExtractTextFilesOnServer" Then
			ConstantName = "ExtractTextFilesOnServer";
			ConstantsSet.ExtractTextFilesOnServer = ExtractTextFilesOnServer;
			Changes = New Structure("Use", ConstantsSet.ExtractTextFilesOnServer);
			ScheduledJobsSave("TextExtraction", Changes, False);
		ElsIf DataPathAttribute = "IndexedDataMaxSize"
			Or DataPathAttribute = "LimitMaxIndexedDataSize" Then
			Try
				If LimitMaxIndexedDataSize Then
					// When you enable the restriction for the first time, the default value of the platform 1 MB is set.
					If IndexedDataMaxSize = 0 Then
						IndexedDataMaxSize = 1;
					EndIf;
					If FullTextSearch.GetMaxIndexedDataSize() <> IndexedDataMaxSize * 1048576 Then
						FullTextSearch.SetMaxIndexedDataSize(IndexedDataMaxSize * 1048576);
					EndIf;
				Else
					FullTextSearch.SetMaxIndexedDataSize(0);
				EndIf;
			Except
				WriteLogEvent(
					NStr("ru = 'Полнотекстовый поиск'; en = 'Full-text search'; pl = 'Wyszukiwanie pełnotekstowe';es_ES = 'Búsqueda de texto completo';es_CO = 'Búsqueda de texto completo';tr = 'Tam metin arama';it = 'Ricerca Full-text';de = 'Volltextsuche'", CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					DetailErrorDescription(ErrorInfo()));
				Result.Insert("CannotEnableFullTextSearchMode", True);
				Return Result;
			EndTry;
		EndIf;
	EndIf;
	
	// Save the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		Result.ConstantName = ConstantName;
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Procedure SetAvailability(DataPathAttribute = "", IndexChecked = False)
	
	If DataPathAttribute = "" Or DataPathAttribute = "UseFullTextSearch" Then
		If ConstantsSet.UseFullTextSearch <> FullTextSearchServer.OperationsAllowed() Then
			UseFullTextSearch = 2;
		Else
			UseFullTextSearch = ConstantsSet.UseFullTextSearch;
		EndIf;
		Items.FullTextSearchManagementGroup.Enabled = (UseFullTextSearch = 1);
		Items.ExtractTextAutomaticallyGroup.Enabled = (UseFullTextSearch = 1);
		
	EndIf;
	
	If DataPathAttribute = ""
		Or DataPathAttribute = "LimitMaxIndexedDataSize"
		Or DataPathAttribute = "IndexedDataMaxSize"
		Or DataPathAttribute = "UseFullTextSearch"
		Or DataPathAttribute = "Command.UpdateIndex"
		Or DataPathAttribute = "Command.ClearIndex"
		Or DataPathAttribute = "Command.CheckIndex" Then
		
		If UseFullTextSearch = 1 Then
			IndexUpdateDate = FullTextSearch.UpdateDate();
			IndexTrue = FullTextSearchServer.SearchIndexIsRelevant();
			FlagAvailability = NOT IndexTrue;
			If IndexChecked AND Not IndexContainsCorrectData Then
				IndexStatus = NStr("ru = 'Требуется очистка и обновление'; en = 'Cleanup and update are required'; pl = 'Wymagane jest wyczyszczenie i aktualizacja';es_ES = 'Se requiere limpiar y actualizar';es_CO = 'Se requiere limpiar y actualizar';tr = 'Temizleme ve güncelleme gerekir';it = 'La pulizia e l''aggiornamento sono richiesti';de = 'Reinigung und Aktualisierung erforderlich'");
			ElsIf IndexTrue Then
				IndexStatus = NStr("ru = 'Обновление не требуется'; en = 'No update required'; pl = 'Aktualizacja nie jest potrzebna';es_ES = 'No se requiere una actualización';es_CO = 'No se requiere una actualización';tr = 'Güncelleme gerekmiyor';it = 'Nessun aggiornamento richiesto';de = 'Update nicht erforderlich'");
			Else
				IndexStatus = NStr("ru = 'Требуется обновление'; en = 'Update required'; pl = 'Wymagana jest aktualizacja';es_ES = 'Actualización requerida';es_CO = 'Actualización requerida';tr = 'Güncelleme gerekiyor';it = 'E'' necessario un aggiornamento';de = 'Aktualisierung erforderlich'");
			EndIf;
		Else
			IndexUpdateDate = '00010101';
			IndexTrue = False;
			FlagAvailability = False;
			IndexStatus = NStr("ru = 'Полнотекстовый поиск отключен'; en = 'Full-text search is disabled'; pl = 'Wyszukiwanie pełnotekstowe jest wyłączone';es_ES = 'Búsqueda de texto completo está desactivada';es_CO = 'Búsqueda de texto completo está desactivada';tr = 'Tam metin araması devre dışı';it = 'Ricerca a testo integrale è disabilitato';de = 'Die Volltextsuche ist deaktiviert'");
		EndIf;
		IndexedDataMaxSize = FullTextSearch.GetMaxIndexedDataSize() / 1048576;
		LimitMaxIndexedDataSize = IndexedDataMaxSize <> 0;
		
		Items.IndexedDataMaxSize.Enabled = LimitMaxIndexedDataSize;
		Items.MBDecoration.Enabled = LimitMaxIndexedDataSize;
		
		If (IndexChecked AND Not IndexContainsCorrectData)
			Or Not IndexTrue Then
			Items.IndexStatus.Font = New Font(, , True);
		Else
			Items.IndexStatus.Font = New Font;
		EndIf;
		
		Items.UpdateIndex.Enabled = FlagAvailability;
		
	EndIf;
	
	If Items.ExtractTextAutomaticallyGroup.Visible
		AND (DataPathAttribute = ""
		Or DataPathAttribute = "ExtractTextFilesOnServer"
		Or DataPathAttribute = "ScheduledJob.TextExtraction") Then
		Items.EditScheduledJob.Enabled = ConstantsSet.ExtractTextFilesOnServer;
		Items.StartTextExtraction.Enabled       = Not ConstantsSet.ExtractTextFilesOnServer;
		If ConstantsSet.ExtractTextFilesOnServer Then
			Information = ScheduledJobsInfo["TextExtraction"];
			SchedulePresentation = String(Information.Schedule);
			SchedulePresentation = Upper(Left(SchedulePresentation, 1)) + Mid(SchedulePresentation, 2);
		Else
			SchedulePresentation = NStr("ru = 'Автоматическое извлечение текстов не выполняется.'; en = 'Automatic text extraction is not performed.'; pl = 'Automatyczne pobieranie tekstów nie jest wykonywane.';es_ES = 'No se realiza la extracción automática de textos.';es_CO = 'No se realiza la extracción automática de textos.';tr = 'Metinlerin otomatik olarak alınması başarısız.';it = 'L''estrazione automatica testo non è eseguita.';de = 'Der automatische Textabruf wird nicht durchgeführt.'");
		EndIf;
		Items.EditScheduledJob.ExtendedTooltip.Title = SchedulePresentation;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillScheduledJobInfo(PredefinedItemName)
	Information = New Structure("ID, Use, Schedule");
	ScheduledJobsInfo.Insert(PredefinedItemName, Information);
	Job = ScheduledJobsFindPredefinedItem(PredefinedItemName);
	If Job = Undefined Then
		Return;
	EndIf;
	Information.ID = Job.UUID;
	Information.Use = Job.Use;
	Information.Schedule    = Job.Schedule;
EndProcedure

&AtServer
Function ScheduledJobsFindPredefinedItem(PredefinedItemName)
	Filter = New Structure("Metadata", PredefinedItemName);
	FoundItems = ScheduledJobsServer.FindJobs(Filter);
	Return ?(FoundItems.Count() = 0, Undefined, FoundItems[0]);
EndFunction

#EndRegion
