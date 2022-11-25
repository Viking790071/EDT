#Region Private

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	List.Parameters.SetParameterValue("Metadata", NStr("en = 'Metadata'; ru = 'Метаданные'; pl = 'Metadane';es_ES = 'Metadatos';es_CO = 'Metadatos';tr = 'Meta veri';it = 'Metadati';de = 'Metadaten'"));
	List.Parameters.SetParameterValue("FunctionalOption", NStr("en = 'Functional option'; ru = 'Функциональная опция'; pl = 'Opcja funkcjonalna';es_ES = 'Opción funcional';es_CO = 'Opción funcional';tr = 'İşlevsel seçenek';it = 'Opzione funzionale';de = 'Funktionale Option'"));
EndProcedure

#EndRegion
