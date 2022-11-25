#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ShouldAskUser = Not DriveReUse.GetValueByDefaultUser(UsersClientServer.CurrentUser(), "EmptyScheduleWithoutMessage");
	
	ErrorInformation = CheckFillWCT(CommandParameter);
	
	FormParameters = New Structure;
	FormParameters.Insert("ArrayProductionOrders", CommandParameter);

	If ShouldAskUser And ErrorInformation.Value Then
		
		QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionParameters.DoNotAskAgain = True;
		QuestionParameters.Title = NStr("en = 'Schedule settings information'; ru = 'Информация настройки расписания';pl = 'Informacje o ustawieniu harmonogramu';es_ES = 'Información sobre los ajustes del horario';es_CO = 'Información sobre los ajustes del horario';tr = 'Planlama ayarları bilgisi';it = 'Informazioni sulle impostazioni di pianificazione';de = 'Einstellungsinformationen planen'");
		
		Notify = New NotifyDescription("PlanningSettingsResponse", ThisObject, FormParameters);
		QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'No work schedule is set for company ""%1"" specified in the ""Work-in-progress"" and related Production order. The 24/7 work schedule will be applied to plan the operations that are not assigned to any work center type.'; ru = 'Для организации ""%1"", указанной в ""Незавершенном производстве"" и соответствующем заказе на производство, не указан график работы. Для планирования операций, которые не назначены ни одному типу рабочего центра, будет применяться график работы 24/7.';pl = 'Nie ustawiono harmonogramu pracy dla firmy ""%1"" określonej w ""Pracy w toku"" i powiązanym Zleceniu produkcyjnym. Harmonogram pracy 24/7 zostanie zastosowany do planowania operacji, które nie są przydzielone do żadnego typu gniazda produkcyjnego.';es_ES = 'No se establece ningún plan de trabajo para la empresa ""%1"" especificada en la Orden de producción ""Trabajo en progreso"" y relacionada. El horario de trabajo 24/7 se aplicará para planificar las operaciones que no estén asignadas a ningún tipo de centro de trabajo.';es_CO = 'No se establece ningún plan de trabajo para la empresa ""%1"" especificada en la Orden de producción ""Trabajo en progreso"" y relacionada. El horario de trabajo 24/7 se aplicará para planificar las operaciones que no estén asignadas a ningún tipo de centro de trabajo.';tr = '""İşlem bitişi""nde ve ilgili Üretim emrinde ""%1"" iş yeri için çalışma programı belirlenmedi. İşlemleri planlamak için, hiçbir iş merkezi türüne atanmamış 7/24 çalışma programı uygulanacak.';it = 'Non è stato impostato alcun piano di lavoro per l''azienda ""%1"" specificata in ""Lavori in corso"" e nel relativo ordine di produzione. Il programma di lavoro 24/7 verrà applicato per pianificare le operazioni che non sono assegnate a nessun tipo di centro di lavoro.';de = 'Für die Firma ""%1"" angegeben in der ""Arbeit in Bearbeitung"" und bezogen auf den Produktionsauftrag ist kein Arbeitszeitplan festgelegt. Der Arbeitsplan 24/7 wird für die Planung der Operationen, die keinem Typ des Arbeitsabschnitts zugeordnet sind, verwendet.'"),
			ErrorInformation.Company);
		StandardSubsystemsClient.ShowQuestionToUser(Notify, QuestionText, QuestionDialogMode.OKCancel, QuestionParameters);
		
	Else
		
		Response = New Structure;
		Response.Insert("Value", DialogReturnCode.OK);
		Response.Insert("DoNotAskAgain", False);
		PlanningSettingsResponse(Response, FormParameters);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure PlanningSettingsResponse(Response, Parameter) Export

	If Response.Value = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Response.DoNotAskAgain Then
		SetUserSettingAtServer(True, "EmptyScheduleWithoutMessage");
	EndIf;

	ArrayProductionOrders = Parameter.ArrayProductionOrders;
	If ArrayProductionOrders.Count() = 1 Then
			
			If OrderUsesPlanning(ArrayProductionOrders[0]) Then
				
				FormParameters = New Structure;
				FormParameters.Insert("ProductionOrder", ArrayProductionOrders[0]);
				
				OpenForm("DataProcessor.ProductionSchedulePlanning.Form.OrderSchedulePlanning", FormParameters);
				
			Else
				
				CommonClientServer.MessageToUser(NStr("en = 'Cannot schedule this order. 
					|Select the Include in production planning check box and try again.'; 
					|ru = 'Не удалось запланировать этот заказ. 
					|Установите флажок ""Включить в планирование производства"" и повторите попытку.';
					|pl = 'Nie można zaplanować tego zamówienia. 
					|Zaznacz pole wyboru Uwzględnij w planowaniu produkcji i spróbuj ponownie.';
					|es_ES = 'No se puede programar esta orden. 
					|Marque la casilla de verificación Incluir en la planificación de la producción e inténtelo de nuevo.';
					|es_CO = 'No se puede programar esta orden. 
					|Marque la casilla de verificación Incluir en la planificación de la producción e inténtelo de nuevo.';
					|tr = 'Bu emir programlanamıyor. 
					|Üretim planlamasına dahil et onay kutusunu işaretleyip tekrar deneyin.';
					|it = 'Impossibile programmare questo ordine. 
					|Seleziona la casella di controllo Includi nella pianificazione della produzione e riprova.';
					|de = 'Dieser Auftrag kann nicht geplant werden. 
					|Aktivieren Sie das Kontrollkästchen In Produktionsplanung einbeziehen, und versuchen Sie es erneut.'"));
				
			EndIf;
			
		ElsIf ArrayProductionOrders.Count() > 1 Then
			
			If OrderUsesPlanning(ArrayProductionOrders[0]) Then
				
				AdditionalParameters = New Structure;
				AdditionalParameters.Insert("ProductionOrders", ArrayProductionOrders);
				
				NotifyDescription = New NotifyDescription("PlanningSettingsEnd", ThisObject, AdditionalParameters);
				OpenForm("DataProcessor.ProductionSchedulePlanning.Form.PlanningSettings", AdditionalParameters,,,,, NotifyDescription);
			
			Else
				
				CommonClientServer.MessageToUser(NStr("en = 'Cannot schedule this order. 
					|Select the Include in production planning check box and try again.'; 
					|ru = 'Не удалось запланировать этот заказ. 
					|Установите флажок ""Включить в планирование производства"" и повторите попытку.';
					|pl = 'Nie można zaplanować tego zamówienia. 
					|Zaznacz pole wyboru Uwzględnij w planowaniu produkcji i spróbuj ponownie.';
					|es_ES = 'No se puede programar esta orden. 
					|Marque la casilla de verificación Incluir en la planificación de la producción e inténtelo de nuevo.';
					|es_CO = 'No se puede programar esta orden. 
					|Marque la casilla de verificación Incluir en la planificación de la producción e inténtelo de nuevo.';
					|tr = 'Bu emir programlanamıyor. 
					|Üretim planlamasına dahil et onay kutusunu işaretleyip tekrar deneyin.';
					|it = 'Impossibile programmare questo ordine. 
					|Seleziona la casella di controllo Includi nella pianificazione della produzione e riprova.';
					|de = 'Dieser Auftrag kann nicht geplant werden. 
					|Aktivieren Sie das Kontrollkästchen In Produktionsplanung einbeziehen, und versuchen Sie es erneut.'"));
				
			EndIf;
			
		EndIf;
	
EndProcedure

&AtClient
Procedure PlanningSettingsEnd(PlanningSettings, AdditionalParameters) Export
	
	If PlanningSettings <> Undefined Then
		
		BackgroundJobDescription = NStr("en = 'Production schedule planning.'; ru = 'Планирование графика производства.';pl = 'Planowanie harmonogramu produkcji.';es_ES = 'Planificación del programa de producción.';es_CO = 'Planificación del programa de producción.';tr = 'Üretim takvimi planlaması.';it = 'Pianificazione della produzione';de = 'Produktionsplanung'");
		
		PlanningSettings.Insert("ProductionOrders", AdditionalParameters.ProductionOrders);
		Result = PlanInBackgroungMode(PlanningSettings);
		
		If Result.Status = "Completed" Or Result.Status = "Error" Then
			
			CheckBackgroungJobCompletion(Result, Undefined);
			
		Else
			
			StartBackgroungJobWaiting(Result);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Function PlanInBackgroungMode(PlanningSettings)
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.WaitForCompletion = 0;
	ExecutionParameters.BackgroundJobDescription = NStr("en = 'Production schedule planning'; ru = 'Планирование графика производства';pl = 'Planowanie harmonogramu produkcji';es_ES = 'Planificación del programa de producción';es_CO = 'Planificación del programa de producción';tr = 'Üretim takvimi planlaması';it = 'Pianificazione della produzione';de = 'Produktionsplanung'");
	
	OperationResult = TimeConsumingOperations.ExecuteInBackground(
		"ProductionPlanningServer.MainPlanAndSaveSeveralOrders",
		PlanningSettings,
		ExecutionParameters);
	
	Return OperationResult;
	
EndFunction

&AtClient
Procedure StartBackgroungJobWaiting(TimeConsumingOperation)
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(Undefined);
	IdleParameters.MessageText = NStr("en = 'Production schedule planning'; ru = 'Планирование графика производства';pl = 'Planowanie harmonogramu produkcji';es_ES = 'Planificación del programa de producción';es_CO = 'Planificación del programa de producción';tr = 'Üretim takvimi planlaması';it = 'Pianificazione della produzione';de = 'Produktionsplanung'");
	IdleParameters.OutputIdleWindow = True;
	
	CompletionNotification = New NotifyDescription("CheckBackgroungJobCompletion", ThisObject);
	TimeConsumingOperationsClient.WaitForCompletion(TimeConsumingOperation, CompletionNotification, IdleParameters);
	
EndProcedure

&AtClient
Procedure CheckBackgroungJobCompletion(Result, ExecuteParameters) Export
	
	If Result = Undefined Or Result.Status = "Canceled" Then
		
		Return;
		
	ElsIf Result.Status = "Error" Then
		
		CommonClientServer.MessageToUser(Result.BriefErrorPresentation);
		
	ElsIf Result.Status = "Completed" Then
		
		ResultStructure = GetFromTempStorage(Result.ResultAddress);
		
		If ResultStructure.PlannedSuccessfully Then
			
			Notify("RefreshProductionOrderQueue", ResultStructure.WIPs);
			ShowPlanningErrors(ResultStructure.ListOfErrorsToShow);
			CommonClientServer.MessageToUser(NStr("en = 'Planned successfully.'; ru = 'Успешно запланировано.';pl = 'Zaplanowano pomyślnie.';es_ES = 'Planificación exitosa.';es_CO = 'Planificación exitosa.';tr = 'Başarıyla planlandı.';it = 'Pianificato con successo.';de = 'Planung erfolgreich.'"));
			
		ElsIf ResultStructure.ErrorsInEventLog Then
			
			ShowMessageErrorsInEventLog();
			
		ElsIf ResultStructure.ErrorsToShow Then
			
			ShowPlanningErrors(ResultStructure.ListOfErrorsToShow);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowPlanningErrors(ListOfErrorsToShow)
	
	For Each ErrorText In ListOfErrorsToShow Do
		
		CommonClientServer.MessageToUser(ErrorText);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure ShowMessageErrorsInEventLog()
	
	ErrorText = NStr("en = 'Something went wrong while planning. Technical info was written to the event log.
		|Proceed to the event log?'; 
		|ru = 'При планировании произошла неизвестная ошибка. Технические сведения записаны в журнал регистрации.
		|Перейти в журнал регистрации?';
		|pl = 'Coś poszło nie tak podczas planowania. Informacje techniczne zostały zapisane do dziennika zmian.
		|Przejść do dziennika wydarzeń?';
		|es_ES = 'Ocurrió un error en la planificación. La información técnica fue grabada en el registro de eventos. 
		|¿Proceder al registro de eventos?';
		|es_CO = 'Ocurrió un error en la planificación. La información técnica fue grabada en el registro de eventos. 
		|¿Proceder al registro de eventos?';
		|tr = 'Planlama sırasında hata oluştu. Teknik bilgiler olay günlüğüne yazıldı.
		|Olay günlüğüne gitmek istiyor musunuz?';
		|it = 'Pianificazione di produzione non riuscita. I dettagli sono salvati nel registro degli eventi.
		|Aprire registro degli eventi?';
		|de = 'Fehlentwicklung beim Planen. Technische Informationen sind im Ereignisprotokoll  eingetragen.
		|Zu Ereignisprotokoll gehen?'");
	Notification = New NotifyDescription("ShowEventLogWhenErrorOccurred", ThisObject);
	ShowQueryBox(Notification, ErrorText, QuestionDialogMode.YesNo, ,DialogReturnCode.No, NStr("en = 'Production planning'; ru = 'Планирование производства';pl = 'Planowanie produkcji';es_ES = 'Planificación de producción';es_CO = 'Planificación de producción';tr = 'Üretim planlaması';it = 'Pianificazione produzione';de = 'Produktionsplanung'"));
	
EndProcedure

&AtClient
Procedure ShowEventLogWhenErrorOccurred(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogEvent", NStr("en = 'Production schedule.Planning'; ru = 'Производственный график.Планирование';pl = 'Harmonogram produkcji.Planowanie';es_ES = 'Production schedule.Planning';es_CO = 'Production schedule.Planning';tr = 'Planlama takvimi.Planlama';it = 'Pianificazione di produzione.Pianificazione';de = 'Produktionsplan.Planung'", CommonClientServer.DefaultLanguageCode()));
		OpenForm("DataProcessor.EventLog.Form", Filter);
		
	EndIf;
	
EndProcedure

&AtServer
Function OrderUsesPlanning(Order)
	
	Return Common.ObjectAttributeValue(Order, "UseProductionPlanning");
	
EndFunction

&AtServer
Procedure SetUserSettingAtServer(SettingValue, SettingName)
	DriveServer.SetUserSetting(SettingValue, SettingName, Users.CurrentUser());
EndProcedure

&AtServer
Function CheckFillWCT(ProductionOrdersArroy)
	
	Query = New Query;
	Query.SetParameter("EmptyCalendars", Catalogs.Calendars.EmptyRef());
	Query.Text = 
	"SELECT TOP 1
	|	Companies.Description AS CompanyDescription
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON ProductionOrder.Company = Companies.Ref
	|WHERE
	|	Companies.BusinessCalendar = &EmptyCalendars";

	ErrorInformation = New Structure;
	ErrorInformation.Insert("Company", "");
	ErrorInformation.Insert("Value", False);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		ErrorInformation.Value = True;
		ErrorInformation.Company = Selection.CompanyDescription;
	EndIf;
	
	Return ErrorInformation;
	
EndFunction

#EndRegion
