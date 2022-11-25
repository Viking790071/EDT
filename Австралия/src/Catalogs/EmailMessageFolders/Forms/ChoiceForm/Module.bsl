
///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CommonClientServer.SetDynamicListFilterItem(List,
	                                                                        "DeletionMark",
	                                                                        False,
	                                                                        DataCompositionComparisonType.Equal,
	                                                                        NStr("ru = 'Отображение только не помеченных на удаление папок'; en = 'Show only folders not marked for deletion'; pl = 'Pokaż tylko foldery nie zaznaczone do usunięcia';es_ES = 'Mostrar sólo las carpetas no marcadas para ser borradas';es_CO = 'Mostrar sólo las carpetas no marcadas para ser borradas';tr = 'Sadece silinmek için işaretlenmeyen klasörleri göster';it = 'Mostrare solo cartelle non contrassegnate per l''eliminazione';de = 'Nur nicht zum Löschen markierte Ordner anzeigen'"),
	                                                                        True, 
	                                                                        DataCompositionSettingsItemViewMode.Inaccessible);
	
EndProcedure

#EndRegion 
