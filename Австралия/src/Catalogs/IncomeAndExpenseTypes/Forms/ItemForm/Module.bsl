
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref.IsEmpty() Then
		DriveServer.ShowMessageAboutError(
			Object,
			NStr("en = 'Cannot create an income and expense type. Creating custom income and expense types is currently restricted.
				|Please, use the predefined income and expense types available in the list.'; 
				|ru = 'Не удалось удалить тип доходов и расходов. Создание пользовательских типов доходов и расходов в настоящее время ограничено.
				|Используйте предопределенные типы доходов и расходов, доступные в списке.';
				|pl = 'Nie można utworzyć typu rozchodów i dochodów. Tworzenie niestandardowych typów dochodów i rozchodów obecnie jest ograniczone.
				|Używaj predefiniowanych typów dochodów i rozchodów, dostępnych na liście.';
				|es_ES = 'No se ha podido crear un tipo de ingresos y gastos. La creación de tipos de ingresos y gastos personalizados está actualmente restringida.
				|Por favor, utilice los tipos de ingresos y gastos predeterminados disponibles en la lista.';
				|es_CO = 'No se ha podido crear un tipo de ingresos y gastos. La creación de tipos de ingresos y gastos personalizados está actualmente restringida.
				|Por favor, utilice los tipos de ingresos y gastos predeterminados disponibles en la lista.';
				|tr = 'Gelir ve gider türü oluşturulamadı. Özel gelir ve gider türleri oluşturma şu anda kısıtlı.
				|Lütfen, listedeki önceden tanımlanmış gelir ve gider türlerini kullanın.';
				|it = 'Impossibile creare un tipo di entrata e uscita. Creare tipi personalizzati di entrata e uscita non è momentaneamente consentito.
				|Utilizzare i tipi disponibili predefiniti di entrata e uscita dall''elenco.';
				|de = 'Fehler beim Löschen des Typs von Einnahme und Ausgaben. Erstellung von Typen von Einnahmen und Ausgaben ist derzeit eingeschränkt.
				|Bitte verwenden Sie die in der Liste verfügbaren vordefinierten Typen von Einnahmen und Ausgaben.'"),
			,
			,
			,
			Cancel);
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
EndProcedure

#EndRegion 

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion