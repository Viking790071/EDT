
#Region Internal

Procedure FindPhaseInTreeByRef(LevelPhasesCollection, PhaseToFind, Index) Export
	
	If TypeOf(Index) = Type("Number") And Index > -1 Then
		Return;
	EndIf;
	
	For Each Phase In LevelPhasesCollection Do
		If Phase.Ref = PhaseToFind Then
			Index = Phase.GetID();
		Else
			FindPhaseInTreeByRef(Phase.GetItems(), PhaseToFind, Index);
		EndIf;
	EndDo;
	
EndProcedure

#Region MessageText

Function NoRightsEditMessageText() Export
	
	Return NStr("en = 'Your user rights are insufficient for editing the project plan. Contact your Administrator.'; ru = 'Ваших прав пользователя недостаточно для редактирования плана проекта. Обратитесь к администратору.';pl = 'Twoje prawa użytkownika są niewystarczające do edytowania planu projektu. Skontaktuj się z twoim Administratorem.';es_ES = 'Sus derechos de usuario son insuficientes para editar el plan del proyecto. Póngase en contacto con su administrador.';es_CO = 'Sus derechos de usuario son insuficientes para editar el plan del proyecto. Póngase en contacto con su administrador.';tr = 'Kullanıcı yetkileriniz proje planını düzenlemek için yetersiz. Yöneticiniz ile irtibata geçin.';it = 'Non si dispone di diritti utente sufficienti per modificare il piano del progetto. Contattare l''Amministratore.';de = 'Ihre Benutzerrechte sind für Bearbeitung des Projektplans unzureichend. Kontaktieren Sie Ihren Administrator.'");
	
EndFunction

Function ProhibitedEditForCompletedMessageText() Export
	
	Return NStr("en = 'The project status is Completed. For such projects, editing is restricted.'; ru = 'Статус проекта – ""Завершен"". Редактирование проекта запрещено.';pl = 'Status projektu jest ustawiony na Zakończono. Dla takich projektów, edytowanie jest ograniczone.';es_ES = 'El estado del proyecto es Finalizado. Para estos proyectos, la edición está restringida.';es_CO = 'El estado del proyecto es Finalizado. Para estos proyectos, la edición está restringida.';tr = 'Projenin durumu Tamamlandı. Bu durumdaki projeler için düzenleme kısıtlıdır.';it = 'Lo stato del progetto è Completato. Per tali progetti le modifiche sono limitate.';de = 'Der Projektstatus ist Abgeschlossen. Für solche Projekte ist Bearbeitung eingeschränkt.'");
	
EndFunction

#EndRegion

#EndRegion