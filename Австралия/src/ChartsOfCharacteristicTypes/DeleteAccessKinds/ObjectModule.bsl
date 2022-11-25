#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

// The BeforeWrite event handler prevents access kinds from being changed. These access kinds can be 
// changed only in Designer mode.
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Raise
		NStr("ru = 'Изменение видов доступа
		           |выполняется только через конфигуратор.
		           |
		           |Удаление допустимо.'; 
		           |en = 'Access kinds can be
		           |changed only using Designer.
		           |
		           |You can remove them.'; 
		           |pl = 'Zmiana rodzajów dostępu
		           |jest wykonywana tylko za pośrednictwem kreatora.
		           |
		           |Usuwanie jest dozwolone.';
		           |es_ES = 'Se puede cambiar los tipos de acceso
		           |solo a través del configurador.
		           |
		           |No se puede eliminar.';
		           |es_CO = 'Se puede cambiar los tipos de acceso
		           |solo a través del configurador.
		           |
		           |No se puede eliminar.';
		           |tr = 'Erişim türleri sadece
		           |Designer''da değiştirilebilir.
		           |
		           |Bunları silebilirsiniz.';
		           |it = 'I tipi di accesso possono essere
		           |modificati solamente utilizzando Designer.
		           |
		           |È possibile rimuoverli.';
		           |de = 'Das Ändern von Zugriffsarten
		           |ist nur über den Konfigurator möglich.
		           |
		           |Das Löschen ist erlaubt.'");
	
EndProcedure

#EndRegion

#EndIf