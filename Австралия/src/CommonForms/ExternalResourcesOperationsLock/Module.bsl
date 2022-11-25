
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ConnectionString = InfoBaseConnectionString();
	SavedParameters = Constants.ExternalResourceAccessLockParameters.Get().Get();
	LockParameters = ScheduledJobsInternal.ExternalResourceAccessLockParameters();
	FillPropertyValues(LockParameters, SavedParameters);
	
	If Parameters.LockDecisionMaking Then
		
		UnlockText = ScheduledJobsInternal.SettingValue("UnlockCommandPlacement");
		DataSeparationEnabled = Common.DataSeparationEnabled();
		DataSeparationChanged = LockParameters.DataSeparationEnabled <> DataSeparationEnabled;
		
		If Not DataSeparationEnabled AND Not DataSeparationChanged Then
			SavedConnectionString = LockParameters.ConnectionString;
			SavedConnectionStringParameters = StringFunctionsClientServer.ParametersFromString(SavedConnectionString);
			If SavedConnectionStringParameters.Property("File") Then
				SavedConnectionString = SavedConnectionStringParameters.File;
			EndIf;
			CurrentConnectionString = ConnectionString;
			CurrentConnectionStringParameters = StringFunctionsClientServer.ParametersFromString(CurrentConnectionString);
			If CurrentConnectionStringParameters.Property("File") Then
				CurrentConnectionString = CurrentConnectionStringParameters.File;
			EndIf;
			LabelTitle = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Размещение информационной базы изменилось с
					|<b>%1</b>
					|на 
					|<b>%2</b>
					|
					|<a href = ""EventLog"">Техническая информация о причине блокировки</a>
					|
					|• Если информационная база будет использоваться для ведения учета, нажмите <b>Информационная база перемещена</b>.
					|• При выборе варианта <b>Это копия информационной базы</b> работа со всеми внешними ресурсами
					|  (синхронизация данных, отправка почты и т.п.), выполняемая по расписанию,
					|  будет заблокирована для предотвращения конфликтов с основой информационной базой.
					|
					|%3'; 
					|en = 'Infobase location was changed from 
					|<b>%1</b>
					|to
					|<b>%2</b>
					|
					|<a href = ""EventLog"">Technical information on lock reason</a>
					|
					|* If the infobase is used for accounting, click <b>Infobase is transferred</b>.
					|* If you select the <b>This is an infobase copy</b> option, operations with all external resources 
					|(data synchronization, email sending, etc.) performed on schedule 
					|will be locked to prevent conflicts with the main infobase.
					|
					|%3'; 
					|pl = 'Lokalizacja bazy informacyjnej zmieniła się z
					|<b>%1</b>
					|na 
					|<b>%2</b>
					|
					|<a href = ""EventLog"">Informacja techniczna o przyczynie blokowania</a>
					|
					|• Jeśli baza informacyjna będzie używana do prowadzenia ewidencji, naciśnij <b>Baza informacyjna została przemieszczona</b>.
					|• W razie wyboru wariantu <b>To jest kopia bazy informacyjnej</b> praca ze wszystkimi zasobami zewnętrznymi
					| (synchronizacja danych, wysyłanie wiadomości e-mail itp.), wykonywana według harmonogramu,
					| zostanie zablokowana w celu uniknięcia konfliktów z główną bazą informacyjną.
					|
					|%3';
					|es_ES = 'Se ha cambiado la situación de la base de información de
					|<b>%1</b>
					|a 
					|<b>%2</b>
					|
					|<a href = ""EventLog"">La información técnica a causa del bloqueo</a>
					|
					|• Si la base de información será realizada para contabilidad, pulse <b>La base de información se ha trasladado</b>.
					|• Al seleccionar la variante <b>Es la copia de la base de información</b> el uso de los recursos externos
					| (sincronización de datos, envío del correo etc), realizado por calendario,
					| será bloqueado para evitar los conflictos con la base de información principal.
					|
					|%3';
					|es_CO = 'Se ha cambiado la situación de la base de información de
					|<b>%1</b>
					|a 
					|<b>%2</b>
					|
					|<a href = ""EventLog"">La información técnica a causa del bloqueo</a>
					|
					|• Si la base de información será realizada para contabilidad, pulse <b>La base de información se ha trasladado</b>.
					|• Al seleccionar la variante <b>Es la copia de la base de información</b> el uso de los recursos externos
					| (sincronización de datos, envío del correo etc), realizado por calendario,
					| será bloqueado para evitar los conflictos con la base de información principal.
					|
					|%3';
					|tr = 'Veritabanın lokasyonu
					|<b>%1</b>
					|''dan 
					|<b>%2</b>
					|
					|<a href = ""EventLog"">Kilitleme nedenine ilişkin teknik bilgiler</a>
					|
					| olarak değişti• Veritabanı muhasebe için kullanılacaksa, <b>Veritabanı taşındı</b>.
					| tıklayın• Seçenek seçildiğinde<b>Bu veritabanın kopyası</b> tüm dış kaynaklar ile plana göre yapılan çalışma
					| (veri eşleşmesi, mail gönderimi vs.),
					| ana veritabanı ile çatışmayı önlemek için kilitlenecektir.
					|
					|%3';
					|it = 'La localizzazione dell''infobase è stata cambiata da 
					|<b>%1</b>
					|in
					|<b>%2</b>
					|
					|<a href = ""EventLog"">Informazioni tecniche sui motivi del blocco</a>
					|
					|* If the infobase is used for accounting, click <b>Infobase is transferred</b>.
					|* If you select the <b>This is an infobase copy</b> option, operations with all external resources 
					|(data synchronization, email sending, etc.) performed on schedule 
					|will be locked to prevent conflicts with the main infobase.
					|
					|%3';
					|de = 'Der Speicherort der Infobase wurde von
					|<b>%1</b>
					|nach
					|<b>%2</b>
					|
					|<a href = ""EventLog"">Technische Informationen über den Sperrgrund</a>
					|
					|* geändert. Wenn die Infobase für die Buchhaltung verwendet wird, klicken Sie auf <b>Infobase wird übertragen</b>.
					|* Wenn Sie die Option<b> Dies ist eine Infobase-Kopie</b> wählen, werden Operationen mit allen externen Ressourcen
					|(Datensynchronisation, E-Mail-Versand, etc.), die nach Zeitplan 
					|ausgeführt, gesperrt, um Konflikte mit der Haupt-Infobase zu vermeiden.
					|
					|%3'"), SavedConnectionString, CurrentConnectionString, UnlockText);
		ElsIf Not DataSeparationEnabled AND DataSeparationChanged Then
			LabelTitle = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Информационная база была загружена из приложения в Интернете
					|
					|• Если информационная база будет использоваться для ведения учета, нажмите <b>Информационная база перемещена</b>.
					|• При выборе варианта <b>Это копия информационной базы</b> работа со всеми внешними ресурсами
					|  (синхронизация данных, отправка почты и т.п.), выполняемая по расписанию,
					|  будет заблокирована для предотвращения конфликтов с приложением в Интернете.
					|
					|%1'; 
					|en = 'Infobase was imported from an online application
					|
					|* If the infobase is used for accounting, click <b>Infobase is transferred</b>.
					|* If you select the <b>This is an infobase copy</b> option, operations with all external resources 
					|(data synchronization, email sending, etc.) performed on schedule 
					|will be locked to prevent conflicts with the online application.
					|
					|%1'; 
					|pl = 'Baza informacyjna została pobrana z aplikacji w Internecie
					|
					|• Jeśli baza informacyjna będzie używana do prowadzenia ewidencji, naciśnij <b>Baza informacyjna została przemieszczona</b>.
					|• W razie wyboru wariantu <b>To jest kopia bazy informacyjnej</b> praca ze wszystkimi zasobami zewnętrznymi
					| (synchronizacja danych, wysyłanie wiadomości e-mail itp.), wykonywana według harmonogramu,
					| zostanie zablokowana w celu uniknięcia konfliktów z aplikacjami w Internecie.
					|
					|%1';
					|es_ES = 'La base de información se ha descargado de la aplicación en Internet
					|
					|• Si la base de información se usará para contabilidad, pulse <b>Si la base de información se ha trasladado</b>.
					|• Al seleccionar la variante <b>Es la copia de la base de información</b> el uso de todos los recursos externos
					|(sincronización de datos, envío del correo etc), realizado por calendario,
					| será bloqueado para evitar los conflictos con la base de información principal.
					|
					|%1';
					|es_CO = 'La base de información se ha descargado de la aplicación en Internet
					|
					|• Si la base de información se usará para contabilidad, pulse <b>Si la base de información se ha trasladado</b>.
					|• Al seleccionar la variante <b>Es la copia de la base de información</b> el uso de todos los recursos externos
					|(sincronización de datos, envío del correo etc), realizado por calendario,
					| será bloqueado para evitar los conflictos con la base de información principal.
					|
					|%1';
					|tr = 'Veritabanı Internet uygulamasından yüklendi
					|
					|• Veritabanı muhasebe için kullanılacaksa <b>Veritabanı taşındı</b>.
					|tıklayın• Seçenek seçildiğinde <b>Bu veritabanın kopyası</b> tüm dış kaynaklar ile plana göre yapılan çalışma
					|(veri eşleşmesi, mail gönderimi vs.),
					|ana veritabanı ile çatışmayı önlemek için kilitlenecektir.
					|
					|%1';
					|it = 'L''infobase è stata importata da una app online
					|
					|* Se l''infobase è utilizzata per la contabilità, cliccare su <b>Infobase trasferita</b>.
					|* Selezionando l''opzione <b>Copia di infobase</b>, le operazioni con tutte le risorse esterni 
					|(sincronizzazione dati, invio email, ecc...) eseguite da grafico 
					|saranno bloccate per prevenire conflitti con l''''applicazione online.
					|
					|%1';
					|de = 'Die Infobase wurde aus einer Anwendung im Internet 
					|
					|heruntergeladen* Wenn die Informationsbasis zum Speichern von Aufzeichnungen verwendet wird, klicken Sie auf <b>Infobasis ist verschoben</b>.
					|* Wenn <b> ausgewählt ist, funktioniert eine Kopie </b> der Infobasis. Die nach dem Zeitplan 
					| durchgeführten Operationen mit allen externen Ressourcen
					|(Datensynchronisierung, Mailversand usw.) , werden gesperrt, um Konflikte mit der Anwendung im Internet zu verhindern.
					|
					|%1'"), UnlockText);
		ElsIf DataSeparationEnabled AND Not DataSeparationChanged Then
			LabelTitle = StringFunctionsClientServer.SubstituteParametersToString(
				NStr(" ru = 'Приложение было перемещено
					|
					|• Если приложение будет использоваться для ведения учета, нажмите <b>Приложение перемещено</b>.
					|• При выборе варианта <b>Это копия приложения</b> работа со всеми внешними ресурсами
					|  (синхронизация данных, отправка почты и т.п.), выполняемая по расписанию,
					|  будет заблокирована для предотвращения конфликтов с приложением в Интернете.
					|
					|%1'; 
					|en = 'The application was transferred
					|
					|* If the application is used for accounting, click <b>Application is transferred</b>.
					|* If you select option <b>This is an application copy</b>, operations with all external resources 
					|(data synchronization, email sending, etc.) performed on schedule  
					|will be locked to prevent conflicts with the online application.
					|
					|%1'; 
					|pl = 'Aplikacja została przemieszczona
					|
					|• Jeśli aplikacja będzie używana do prowadzenia ewidencji, naciśnij <b>Aplikacja została przemieszczona</b>.
					|• W razie wyboru wariantu <b>To jest kopia aplikacji</b> praca ze wszystkimi zasobami zewnętrznymi
					| (synchronizacja danych, wysyłanie wiadomości e-mail itp.), wykonywana według harmonogramu,
					| zostanie zablokowana w celu uniknięcia konfliktów z aplikacjami w Internecie.
					|
					|%1';
					|es_ES = 'La aplicación se ha trasladado
					|
					|• Si la aplicación se usará para la contabilidad, pulse <b>Aplicación trasladada</b>.
					|• Al seleccionar la variante <b>Es la copia de la aplicación</b> el uso de todos los recursos externos
					|(sincronización de datos, envío del correo etc), realizado por calendario,
					| será bloqueado para evitar los conflictos con la base de información principal.
					|
					|%1';
					|es_CO = 'La aplicación se ha trasladado
					|
					|• Si la aplicación se usará para la contabilidad, pulse <b>Aplicación trasladada</b>.
					|• Al seleccionar la variante <b>Es la copia de la aplicación</b> el uso de todos los recursos externos
					|(sincronización de datos, envío del correo etc), realizado por calendario,
					| será bloqueado para evitar los conflictos con la base de información principal.
					|
					|%1';
					|tr = 'Uygulama taşındı
					|
					|• Veritabanı muhasebe için kullanılacaksa <b>Uygulama taşındı</b>.
					|tıklayın• Seçenek seçildiğinde <b>Bu veritabanın kopyası</b> tüm dış kaynaklar ile plana göre yapılan çalışma
					|(veri eşleşmesi, mail gönderimi vs.),
					|ana veritabanı ile çatışmayı önlemek için kilitlenecektir.
					|
					|%1';
					|it = 'L''applicazione è stata trasferita
					|
					|* Se l''applicazione è utilizzata per la contabilità, cliccare su <b> L''applicazione è stat trasferita</b>.
					|* Selezionando l''opzione <b> Questa è una copia dell''applicazione</b>, operazioni con tutte le risorse esterne 
					| (sincronizzazione dati, invio email, ecc...) eseguito da grafico  
					| sarà bloccato per evitare conflitti con l''applicazione online.
					|
					|%1';
					|de = 'Die Anwendung wurde verschoben
					|
					|• Wenn die Anwendung für die Abrechnung verwendet wird, klicken Sie auf <b>Anwendung verschoben</b>.
					|• Wenn diese Option ausgewählt ist wird <b>Diese Kopie der Anwendung</b> die zeitgesteuerte Arbeit mit allen externen Ressourcen
					|(Datensynchronisierung, E-Mail-Versand usw.)
					|blockieren, um Konflikte mit der Anwendung im Internet zu vermeiden.
					|
					|%1'"), UnlockText);
			Items.InfobaseMoved.Title = NStr("ru = 'Приложение перемещено'; en = 'Application is transferred'; pl = 'Aplikacja została przemieszczona';es_ES = 'Aplicación trasladada';es_CO = 'Aplicación trasladada';tr = 'Uygulama taşındı';it = 'Applicazione spostata';de = 'Die Anwendung wurde verschoben.'");
			Items.IsInfobaseCopy.Title = NStr("ru = 'Это копия приложения'; en = 'This is an application copy'; pl = 'To jest kopia aplikacji';es_ES = 'Es la copia de la aplicación';es_CO = 'Es la copia de la aplicación';tr = 'Bu uygulamanın kopyası';it = 'Questa è una copia dell''applicazione';de = 'Dies ist eine Kopie der Anwendung'");
			Title = NStr("ru = 'Приложение было перемещено или восстановлено из резервной копии'; en = 'The application was transferred or restored from the backup'; pl = 'Aplikacja została przemieszczona albo odzyskana z kopii zapasowej';es_ES = 'La aplicación ha sido trasladada o restablecida de la copia de reserva';es_CO = 'La aplicación ha sido trasladada o restablecida de la copia de reserva';tr = 'Uygulama taşındı veya yedek kopyadan yenilendi';it = 'L''applicazione è stata trasferita o ripristinata dal backup';de = 'Die Anwendung wurde aus der Sicherung verschoben oder wiederhergestellt'");
		Else // If DataSeparationEnabled and DataSeparationChanged
			LabelTitle = StringFunctionsClientServer.SubstituteParametersToString(
				NStr(" ru = 'Приложение было загружено из локальной версии
					|
					|• Если приложение будет использоваться для ведения учета, нажмите <b>Приложение перемещено</b>.
					|• При выборе варианта <b>Это копия приложения</b> работа со всеми внешними ресурсами
					|  (синхронизация данных, отправка почты и т.п.), выполняемая по расписанию,
					|  будет заблокирована для предотвращения конфликтов с локальной версией.
					|
					|%1'; 
					|en = 'The application was imported from the local version
					|
					|* If the application is used for accounting, click <b>Application is transferred</b>.
					|* If you choose option <b>This is an application copy</b>, operations with all external resources 
					|(data synchronization, email sending, etc.) performed on schedule 
					|will be locked to prevent conflicts with local version.
					|
					|%1'; 
					|pl = 'Aplikacja została pobrana z wersji lokalnej
					|
					|• Jeśli aplikacja będzie używana do prowadzenia ewidencji, naciśnij <b>Aplikacja została przemieszczona</b>.
					|• W razie wyboru wariantu <b>To jest kopia aplikacji</b> praca ze wszystkimi zasobami zewnętrznymi
					| (synchronizacja danych, wysyłanie wiadomości e-mail itp.), wykonywana według harmonogramu,
					| zostanie zablokowana w celu uniknięcia konfliktów z wersją lokalną.
					|
					|%1';
					|es_ES = 'La aplicación ha sido descargada de la versión local
					|
					|• Si la aplicación se usará para la contabilidad, pulse <b>Aplicación trasladada</b>.
					|• Al seleccionar la variante <b>Es la copia de la aplicación</b> el uso de todos los recursos externos
					|(sincronización de datos, envío del correo etc), realizado por calendario,
					| será bloqueado para evitar los conflictos con la base de información principal.
					|
					|%1';
					|es_CO = 'La aplicación ha sido descargada de la versión local
					|
					|• Si la aplicación se usará para la contabilidad, pulse <b>Aplicación trasladada</b>.
					|• Al seleccionar la variante <b>Es la copia de la aplicación</b> el uso de todos los recursos externos
					|(sincronización de datos, envío del correo etc), realizado por calendario,
					| será bloqueado para evitar los conflictos con la base de información principal.
					|
					|%1';
					|tr = 'Uygulama lokal sürümden yüklendi
					|
					|• Uygulama muhasebe için kullanılacaksa <b>Uygulama taşındı</b>.
					|tıklayın• Seçenek seçildiğinde <b>Bu veritabanın kopyası</b> tüm dış kaynaklar ile plana göre yapılan çalışma
					|(veri eşleşmesi, mail gönderimi vs.),
					|ana veritabanı ile çatışmayı önlemek için kilitlenecektir.
					|
					|%1';
					|it = 'L''applicazione è stata importata dalla versione locale
					|
					|* Se l''applicazione è utilizzata per la contabilità, cliccare su <b>Applicazione trasferita</b>.
					|* Selezionando l''opzione <b>Copia di applicazione</b>, le operazioni con tutte le risorse esterne 
					|(sincronizzazione dati, invio email, ecc...) eseguite da grafico
					| saranno bloccate per prevenire conflitti con la versione locale.
					|
					|%1';
					|de = 'Die Anwendung wurde von der lokalen Version heruntergeladen
					|
					|• Wenn die Anwendung für Abrechnungszwecke verwendet werden soll, klicken Sie auf <b>Die Anwendung wurde verschoben</b>.
					|• Wenn Sie die Option <b>Dies ist eine Kopie der Anwendung</b>, die mit allen externen Ressourcen arbeitet
					|(Datensynchronisation, Mailversand, etc.) wählen, die gemäß dem Zeitplan ausgeführt wird,
					|wird gesperrt, um Konflikte mit der lokalen Version zu vermeiden.
					|
					|%1'"), UnlockText);
			Items.InfobaseMoved.Title = NStr("ru = 'Приложение перемещено'; en = 'Application is transferred'; pl = 'Aplikacja została przemieszczona';es_ES = 'Aplicación trasladada';es_CO = 'Aplicación trasladada';tr = 'Uygulama taşındı';it = 'Applicazione spostata';de = 'Die Anwendung wurde verschoben.'");
			Items.IsInfobaseCopy.Title = NStr("ru = 'Это копия приложения'; en = 'This is an application copy'; pl = 'To jest kopia aplikacji';es_ES = 'Es la copia de la aplicación';es_CO = 'Es la copia de la aplicación';tr = 'Bu uygulamanın kopyası';it = 'Questa è una copia dell''applicazione';de = 'Dies ist eine Kopie der Anwendung'");
			Title = NStr("ru = 'Приложение было перемещено или восстановлено из резервной копии'; en = 'The application was transferred or restored from the backup'; pl = 'Aplikacja została przemieszczona albo odzyskana z kopii zapasowej';es_ES = 'La aplicación ha sido trasladada o restablecida de la copia de reserva';es_CO = 'La aplicación ha sido trasladada o restablecida de la copia de reserva';tr = 'Uygulama taşındı veya yedek kopyadan yenilendi';it = 'L''applicazione è stata trasferita o ripristinata dal backup';de = 'Die Anwendung wurde aus der Sicherung verschoben oder wiederhergestellt'");
		EndIf;
		
		Items.WarningLabel.Title = StringFunctionsClientServer.FormattedString(LabelTitle);
		
		If Common.FileInfobase(ConnectionString) Then
			Items.FormMoreGroup.Visible = False;
		Else
			Items.FormHelp.Visible = False;
		EndIf;
		
	Else
		Items.FormParametersGroup.CurrentPage = Items.LockParametersGroup;
		Items.WarningLabel.Visible = False;
		Items.WriteAndClose.DefaultButton = True;
		Title = NStr("ru = 'Параметры блокировки работы с внешними ресурсами'; en = 'External resource lock settings'; pl = 'Parametry blokowania pracy z zasobami zewnętrznymi';es_ES = 'Los parámetros del bloqueo del uso de los recursos externos';es_CO = 'Los parámetros del bloqueo del uso de los recursos externos';tr = 'Dış kaynak kilitleme seçenekleri';it = 'Impostazioni blocco risorse esterne';de = 'Parameter für die Sperrrung der Arbeit mit externen Ressourcen'");
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then
		
		Items.Move(Items.InfobaseMoved, Items.MobileClientGroup);
		
		Items.FormHelp.Visible = False;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure TextWarningURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("EventLogEvent",
		NStr("ru = 'Работа с внешними ресурсами заблокирована'; en = 'Operations with external resources have been locked'; pl = 'Praca z zasobami zewnętrznymi jest zablokowana';es_ES = 'El uso de los recursos externos ha sido bloqueado';es_CO = 'El uso de los recursos externos ha sido bloqueado';tr = 'Dış kaynaklarla çalışma kilitlendi';it = 'Le operazioni con risorse esterno sono state bloccate';de = 'Die Arbeit mit externen Ressourcen ist gesperrt.'",
		CommonClientServer.DefaultLanguageCode()));
	OpenForm("DataProcessor.EventLog.Form.EventLog", FormParameters);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure InfobaseMoved(Command)
	InfobaseMovedAtServer();
	StandardSubsystemsClient.SetAdvancedApplicationCaption();
	RefreshInterface();
	Close();
EndProcedure

&AtClient
Procedure IsInfobaseCopy(Command)
	IsInfobaseCopyAtServer();
	StandardSubsystemsClient.SetAdvancedApplicationCaption();
	RefreshInterface();
	Close();
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	WriteAndCloseAtServer();
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure InfobaseMovedAtServer()
	
	ScheduledJobsInternal.AllowOperationsWithExternalResources(LockParameters);
	
EndProcedure

&AtServer
Procedure IsInfobaseCopyAtServer()
	
	JobDependencies = ScheduledJobsInternal.ScheduledJobsDependentOnFunctionalOptions();
	FoundRows = JobDependencies.FindRows(New Structure("UseExternalResources", True));
	ProcessedJobs = New Map;
	
	For Each JobRow In FoundRows Do
		If ProcessedJobs.Get(JobRow.ScheduledJob) <> Undefined Then
			Continue; // The job was disabled.
		EndIf;
		ProcessedJobs.Insert(JobRow.ScheduledJob);
		
		Filter = New Structure;
		Filter.Insert("Use", True);
		Filter.Insert("Metadata", JobRow.ScheduledJob);
		Jobs = ScheduledJobsServer.FindJobs(Filter);
		
		JobParameters = New Structure("Use", False);
		For Each Job In Jobs Do
			ScheduledJobsServer.ChangeJob(Job.UUID, JobParameters);
			LockParameters.DisabledJobs.Add(Job.UUID);
		EndDo;
		
	EndDo;
	LockParameters.OperationsWithExternalResourcesLocked = True;
	ValueStorage = New ValueStorage(LockParameters);
	Constants.ExternalResourceAccessLockParameters.Set(ValueStorage);
	
	// If this is a copy of the infobase, update the infobase ID.
	InfobaseID = New UUID();
	Constants.InfoBaseID.Set(String(InfobaseID));
	
	RefreshReusableValues();
EndProcedure

&AtServer
Procedure WriteAndCloseAtServer()
	ValueStorage = New ValueStorage(LockParameters);
	Constants.ExternalResourceAccessLockParameters.Set(ValueStorage);
EndProcedure

#EndRegion
