
#Region FormCommandsEventHandlers

&AtClient
Procedure BackToWork(Command)
	Close();
EndProcedure

&AtClient
Procedure OK(Command)
	
	If Not ValueIsFilled(RejectionReason) Then
		CommonClientServer.MessageToUser(NStr("en = 'The Rejection reason field is required.'; ru = 'Не заполнено поле Причина отклонения.';pl = 'Pole Przyczyna odrzucenia jest wymagane.';es_ES = 'El campo razón de Denegación es obligatorio.';es_CO = 'El campo razón de Denegación es obligatorio.';tr = 'Reddetme sebebi alanı zorunludur.';it = 'È richiesto il campo Motivo di rifiuto.';de = 'Das Feld Ablehnungsgrund ist erforderlich.'"));
		Return;
	EndIf;
	
	RejectedLeadData = New Structure;
	RejectedLeadData.Insert("RejectionReason", RejectionReason);
	RejectedLeadData.Insert("ClosureNote", ClosureNote);
	
	Close(RejectedLeadData);
	
EndProcedure

#EndRegion
