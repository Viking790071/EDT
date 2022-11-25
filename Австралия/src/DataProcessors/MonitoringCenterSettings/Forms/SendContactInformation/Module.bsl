#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	MonitoringCenterParameters = New Structure("ContactInformation, ContactInformationComment1");
	MonitoringCenterParameters = MonitoringCenterInternal.GetMonitoringCenterParameters(MonitoringCenterParameters);
	Contacts = MonitoringCenterParameters.ContactInformation;
	Comment = MonitoringCenterParameters.ContactInformationComment1;
	If Common.SubsystemExists("OnlineUserSupport") Then
		ModuleOnlineUserSupport = Common.CommonModule("OnlineUserSupport");
		AuthenticationData = ModuleOnlineUserSupport.OnlineSupportUserAuthenticationData();
		If AuthenticationData <> Undefined Then
			Username2 = AuthenticationData.Username2;
		EndIf;
	EndIf;
	If Parameters.Property("OnRequest") Then
		OnRequest = True;
		Items.Title.Title = NStr("ru = 'Ранее Вы подписались на отправку анонимных обезличенных отчетов об использовании программы. В результате анализа предоставленных отчетов выявлены проблемы производительности. Если Вы готовы предоставить фирме ""1С"" копию Вашей информационной базы (может быть обезличена) для расследования проблем производительности, пожалуйста, укажите свои контактные данные, чтобы сотрудники фирмы ""1С"" могли с Вами связаться.
                                             |Если Вы откажетесь, никакие идентификационные данные не будут отправлены.';
											|en = 'Earlier you signed up to send anonymous depersonalized reports about the application usage. The analysis of the submitted reports revealed performance issues. If you are ready to submit a copy of your infobase (can be depersonalized) to 1C Company to get your performance issues looked into, please specify your contact details so that 1C Company employees can contact you.
											|If you refuse, no identification data will be sent.';pl = 'Wcześniej podpisałeś się na wysyłkę anonimowych zdepersonalizowanych raportów dotyczących użycia aplikacji. W wyniku przeanalizowanych raportów wykryto problemy wydajności. Jeśli chcesz przesłać kopię twojej bazy informacyjnej (można ją zdepersonalizować) do 1C Company w celu zbadania problemów z wydajnością, podaj dane kontaktowe, aby pracownicy 1C Company mogli skontaktować się z tobą.
                                             |W razie odmowy żadne dane identyfikacyjne nie będą wysłane.';
                                             |es_ES = 'Anteriormente, usted se inscribió para enviar informes anónimos despersonalizados sobre el uso de la aplicación. El análisis de los informes enviados reveló problemas de rendimiento. Si está dispuesto a enviar una copia de su base de información (no personalizada) a 1C Company para que se analicen sus problemas de rendimiento, especifique sus datos de contacto para que los empleados de 1C Company puedan ponerse en contacto con usted.
                                             |Si no quiere, no se enviarán datos de identificación.';
                                             |es_CO = 'Anteriormente, usted se inscribió para enviar informes anónimos despersonalizados sobre el uso de la aplicación. El análisis de los informes enviados reveló problemas de rendimiento. Si está dispuesto a enviar una copia de su base de información (no personalizada) a 1C Company para que se analicen sus problemas de rendimiento, especifique sus datos de contacto para que los empleados de 1C Company puedan ponerse en contacto con usted.
                                             |Si no quiere, no se enviarán datos de identificación.';
                                             |tr = 'Daha önce, uygulama kullanımı hakkında isimsiz kişiselleştirilmiş raporlar göndermek için kaydoldunuz. Sunulan raporların analizi performans sorunları ortaya koyuyor. Performans sorunlarınızın incelenmesi için Infobase''inizin bir kopyasını (kişiliksizleştirilmiş olabilir) 1C Şirketine göndermeye hazırsanız, lütfen 1C Şirketi çalışanlarının sizinle iletişime geçebilmesi için iletişim bilgilerinizi belirtin.
                                             |Reddederseniz, tanımlama verileri gönderilmeyecek.';
                                             |it = 'Hai precedentemente acconsentito all''invio di report anonimi spersonalizzati sull''utilizzo dell''applicazione. L''analisi dei report trasmessi ha rilevato dei problemi di prestazione. Per trasmettere una copia del tuo infobase (può essere spersonalizzato) a 1C per una verifica dei tuoi problemi di prestazione, indicare i tuoi dettagli di contatto per essere ricontattato dai dipendenti di 1C.
                                             |Rifiutando non saranno inviati dati di identificazione.';
                                             |de = 'Früher haben Sie Sich für Senden von depersonalisiereten Berichten über Verwenden der Anwendung angemeldet. Die Analyse von eingereichten Berichten zeigte Leistungsprobleme. Sind Sie bereit eine Kopie Ihrer Infobase (die depersonalisiert sein kann) an 1C Company zum Überprüfen Ihrer Leistungsprobleme zu senden, geben Sie bitte Ihre Kontaktinformationen ein, damit die Mitarbeiter von 1C Company Sie kontaktieren können.
                                             | Verweigern Sie, werden keine Identifikationsdaten gesendet.'");
		Items.FormSend.Title = NStr("ru = 'Отправить контактную информацию';
												|en = 'Send contact information';pl = 'Wyślij informacje kontaktowe';es_ES = 'Enviar información contacto';es_CO = 'Enviar información contacto';tr = 'İletişim bilgilerini gönder';it = 'Inviare informazioni di contatto';de = 'Kontaktinformationen senden'");
	Else
		Items.Comment.InputHint = NStr("ru = 'Опишите проблему';
													|en = 'Describe your issue';pl = 'Opisz twój problem';es_ES = 'Describa su problema';es_CO = 'Describa su problema';tr = 'Sorunu açıklayın';it = 'Descrizione errore';de = 'Beschreiben Sie Ihr Problem'");
		Items.FormCancel13.Visible = False;
		Items.Contacts.AutoMarkIncomplete = True;
		Items.Comment.AutoMarkIncomplete = True;
	EndIf;
	ResetWindowLocationAndSize();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Send(Command) 
	If Not FilledCorrectly1() Then
		Return;
	EndIf;
	NewParameters = New Structure;
	NewParameters.Insert("ContactInformationRequest", 1);
	NewParameters.Insert("ContactInformationChanged", True);
	NewParameters.Insert("ContactInformation", Contacts);
	NewParameters.Insert("ContactInformationComment1", Comment);
	NewParameters.Insert("PortalUsername", Username2);
	SetMonitoringCenterParameters(NewParameters);
	Close();
EndProcedure

&AtClient
Procedure Cancel(Command)
	NewParameters = New Structure;
	NewParameters.Insert("ContactInformationRequest", 0);
	NewParameters.Insert("ContactInformationChanged", True);
	NewParameters.Insert("ContactInformation", "");
	NewParameters.Insert("ContactInformationComment1", Comment);
	SetMonitoringCenterParameters(NewParameters);
	Close();
EndProcedure

#EndRegion

#Region Private

&AtClient
Function FilledCorrectly1()
	CheckResult = True;
	If OnRequest Then
		If IsBlankString(Contacts)Then
			CommonClientServer.MessageToUser(NStr("ru = 'Не указана контактная информация.';
															|en = 'Contact information is not specified.';pl = 'Nie określono informacji kontaktowych.';es_ES = 'No se especifica la información de contacto.';es_CO = 'No se especifica la información de contacto.';tr = 'İletişim bilgileri belirtilmedi.';it = 'Informazioni di contatto non indicate.';de = 'Kontaktinformationen sind nicht eingegeben.'"),,"Contacts");
			CheckResult = False;
		EndIf; 
	Else 
		If IsBlankString(Contacts)Then
			CommonClientServer.MessageToUser(NStr("ru = 'Не указана контактная информация.';
															|en = 'Contact information is not specified.';pl = 'Nie określono informacji kontaktowych.';es_ES = 'No se especifica la información de contacto.';es_CO = 'No se especifica la información de contacto.';tr = 'İletişim bilgileri belirtilmedi.';it = 'Informazioni di contatto non indicate.';de = 'Kontaktinformationen sind nicht eingegeben.'"),,"Contacts");
			CheckResult = False;
		EndIf; 
		If IsBlankString(Comment)Then
			CommonClientServer.MessageToUser(NStr("ru = 'Не заполнен комментарий.';
															|en = 'Comment is not filled in.';pl = 'Uwagi nie są wypełnione.';es_ES = 'No se ha rellenado el comentario.';es_CO = 'No se ha rellenado el comentario.';tr = 'Yorum doldurulmadı.';it = 'Commento non compilato.';de = 'Kommentar ist nicht ausgefüllt.'"),,"Comment");
			CheckResult = False;
		EndIf; 
	EndIf;
	Return CheckResult;
EndFunction

&AtServer
Procedure ResetWindowLocationAndSize()
	WindowOptionsKey = ?(OnRequest, "OnRequest", "Independent1");
EndProcedure

&AtServerNoContext
Procedure SetMonitoringCenterParameters(NewParameters)
	MonitoringCenterInternal.SetMonitoringCenterParametersExternalCall(NewParameters);
EndProcedure

#EndRegion