local currentCameraIndex = 0
local createdCamera = 0

local function GetCurrentTime()
    local hours = GetClockHours()
    local minutes = GetClockMinutes()
    if hours < 10 then
        hours = tostring(0 .. GetClockHours())
    end
    if minutes < 10 then
        minutes = tostring(0 .. GetClockMinutes())
    end
    return tostring(hours .. ":" .. minutes)
end

local function ChangeSecurityCamera(x, y, z, r)
    if createdCamera ~= 0 then
        DestroyCam(createdCamera, 0)
        createdCamera = 0
    end

    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", 1)
    SetCamCoord(cam, x, y, z)
    SetCamRot(cam, r.x, r.y, r.z, 2)
    RenderScriptCams(1, 0, 0, 1, 1)
    Wait(250)
    createdCamera = cam
end

local function CloseSecurityCamera()
    DestroyCam(createdCamera, 0)
    RenderScriptCams(0, 0, 1, 1, 1)
    createdCamera = 0
    ClearTimecycleModifier("scanline_cam_cheap")
    SetFocusEntity(GetPlayerPed(PlayerId()))
    if Config.SecurityCameras.hideradar then
        DisplayRadar(true)
    end
    FreezeEntityPosition(GetPlayerPed(PlayerId()), false)
end

local function InstructionButton(ControlButton)
    N_0xe83a3e3557a56640(ControlButton)
end

local function InstructionButtonMessage(text)
    BeginTextCommandScaleformString("STRING")
    AddTextComponentScaleform(text)
    EndTextCommandScaleformString()
end

local function CreateInstuctionScaleform(scaleform)
    local scaleform = RequestScaleformMovie(scaleform)
    while not HasScaleformMovieLoaded(scaleform) do
        Wait(0)
    end
    PushScaleformMovieFunction(scaleform, "CLEAR_ALL")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_CLEAR_SPACE")
    PushScaleformMovieFunctionParameterInt(200)
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(1)
    InstructionButton(GetControlInstructionalButton(1, 194, true))
    InstructionButtonMessage(Lang:t('info.close_camera'))
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "DRAW_INSTRUCTIONAL_BUTTONS")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_BACKGROUND_COLOUR")
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(80)
    PopScaleformMovieFunctionVoid()

    return scaleform
end

-- Events
RegisterNetEvent('police:client:ActiveCamera', function(cameraId)
    if Config.SecurityCameras.cameras[cameraId] then
        DoScreenFadeOut(250)
        while not IsScreenFadedOut() do
            Wait(0)
        end
        SendNUIMessage({
            type = "enablecam",
            label = Config.SecurityCameras.cameras[cameraId].label,
            id = cameraId,
            connected = Config.SecurityCameras.cameras[cameraId].isOnline,
            time = GetCurrentTime(),
        })
        local firstCamx = Config.SecurityCameras.cameras[cameraId].coords.x
        local firstCamy = Config.SecurityCameras.cameras[cameraId].coords.y
        local firstCamz = Config.SecurityCameras.cameras[cameraId].coords.z
        local firstCamr = Config.SecurityCameras.cameras[cameraId].r
        SetFocusArea(firstCamx, firstCamy, firstCamz, firstCamx, firstCamy, firstCamz)
        ChangeSecurityCamera(firstCamx, firstCamy, firstCamz, firstCamr)
        currentCameraIndex = cameraId
        DoScreenFadeIn(250)
    elseif cameraId == 0 then
        DoScreenFadeOut(250)
        while not IsScreenFadedOut() do
            Wait(0)
        end
        CloseSecurityCamera()
        SendNUIMessage({
            type = "disablecam",
        })
        DoScreenFadeIn(250)
    else
        QBCore.Functions.Notify(Lang:t("error.no_camera"), "error")
    end
end)

RegisterNetEvent('police:client:DisableAllCameras', function()
    for k, v in pairs(Config.SecurityCameras.cameras) do 
        Config.SecurityCameras.cameras[k].isOnline = false
    end
end)

RegisterNetEvent('police:client:EnableAllCameras', function()
    for k, v in pairs(Config.SecurityCameras.cameras) do 
        Config.SecurityCameras.cameras[k].isOnline = true
    end
end)

RegisterNetEvent('police:client:SetCamera', function(key, isOnline)
    Config.SecurityCameras.cameras[key].isOnline = isOnline
end)

-- Threads
CreateThread(function()
    while true do
        sleep = 2000
        if createdCamera ~= 0 then
            sleep = 5
            local instructions = CreateInstuctionScaleform("instructional_buttons")
            DrawScaleformMovieFullscreen(instructions, 255, 255, 255, 255, 0)
            SetTimecycleModifier("scanline_cam_cheap")
            SetTimecycleModifierStrength(1.0)

            if Config.SecurityCameras.hideradar then
                DisplayRadar(false)
            end

            -- CLOSE CAMERAS
            if IsControlJustPressed(1, 177) then
                DoScreenFadeOut(250)
                while not IsScreenFadedOut() do
                    Wait(0)
                end
                CloseSecurityCamera()
                SendNUIMessage({
                    type = "disablecam",
                })
                DoScreenFadeIn(250)
            end

            ---------------------------------------------------------------------------
            -- CAMERA ROTATION CONTROLS
            ---------------------------------------------------------------------------
            if Config.SecurityCameras.cameras[currentCameraIndex].canRotate then
                local getCameraRot = GetCamRot(createdCamera, 2)

                -- ROTATE UP
                if IsControlPressed(0, 32) then
                    if getCameraRot.x <= 0.0 then
                        SetCamRot(createdCamera, getCameraRot.x + 0.7, 0.0, getCameraRot.z, 2)
                    end
                end

                -- ROTATE DOWN
                if IsControlPressed(0, 8) then
                    if getCameraRot.x >= -50.0 then
                        SetCamRot(createdCamera, getCameraRot.x - 0.7, 0.0, getCameraRot.z, 2)
                    end
                end

                -- ROTATE LEFT
                if IsControlPressed(0, 34) then
                    SetCamRot(createdCamera, getCameraRot.x, 0.0, getCameraRot.z + 0.7, 2)
                end

                -- ROTATE RIGHT
                if IsControlPressed(0, 9) then
                    SetCamRot(createdCamera, getCameraRot.x, 0.0, getCameraRot.z - 0.7, 2)
                end
            end
        end
        Wait(sleep)
    end
end)




RegisterNetEvent('police:store:cams')
AddEventHandler('police:store:cams', function(police)
    local ped = PlayerPedId()
    local model = GetEntityModel(PlayerPedId())
    local cam = police.cam
    if cam == '1' then
        TriggerEvent("police:client:ActiveCamera", 1)
    elseif cam == '2' then
        TriggerEvent("police:client:ActiveCamera", 2)
    elseif cam == '3' then
        TriggerEvent("police:client:ActiveCamera", 3)
    elseif cam == '4' then
        TriggerEvent("police:client:ActiveCamera", 4)
    elseif cam == '5' then
        TriggerEvent("police:client:ActiveCamera", 5)
    elseif cam == '6' then
        TriggerEvent("police:client:ActiveCamera", 6)
    elseif cam == '7' then
        TriggerEvent("police:client:ActiveCamera", 7)
    elseif cam == '8' then
        TriggerEvent("police:client:ActiveCamera", 8)
    elseif cam == '9' then
        TriggerEvent("police:client:ActiveCamera", 9)
    elseif cam == '10' then
        TriggerEvent("police:client:ActiveCamera", 10)
    elseif cam == '11' then
        TriggerEvent("police:client:ActiveCamera", 11)
    elseif cam == '12' then
        TriggerEvent("police:client:ActiveCamera", 12)
    elseif cam == '13' then
        TriggerEvent("police:client:ActiveCamera", 13)
    elseif cam == '14' then
        TriggerEvent("police:client:ActiveCamera", 14)
    elseif cam == '15' then
        TriggerEvent("police:client:ActiveCamera", 15)
    elseif cam == '16' then
        TriggerEvent("police:client:ActiveCamera", 16)
    elseif cam == '17' then
        TriggerEvent("police:client:ActiveCamera", 17)
    elseif cam == '18' then
        TriggerEvent("police:client:ActiveCamera", 18)
    elseif cam == '19' then
        TriggerEvent("police:client:ActiveCamera", 19)
    elseif cam == '20' then
        TriggerEvent("police:client:ActiveCamera", 20)
    elseif cam == '21' then
        TriggerEvent("police:client:ActiveCamera", 21)
    elseif cam == '22' then
        TriggerEvent("police:client:ActiveCamera", 22)
    elseif cam == '23' then
        TriggerEvent("police:client:ActiveCamera", 23)
    elseif cam == '24' then
        TriggerEvent("police:client:ActiveCamera", 24)
    elseif cam == '25' then
        TriggerEvent("police:client:ActiveCamera", 25)
    elseif cam == '26' then
        TriggerEvent("police:client:ActiveCamera", 26)
    elseif cam == '27' then
        TriggerEvent("police:client:ActiveCamera", 27)
    elseif cam == '28' then
        TriggerEvent("police:client:ActiveCamera", 28)
    elseif cam == '29' then
        TriggerEvent("police:client:ActiveCamera", 29)
    elseif cam == '30' then
        TriggerEvent("police:client:ActiveCamera", 30)
    elseif cam == '31' then
        TriggerEvent("police:client:ActiveCamera", 31)
    elseif cam == '32' then
        TriggerEvent("police:client:ActiveCamera", 32)
    elseif cam == '33' then
        TriggerEvent("police:client:ActiveCamera", 33)
    elseif cam == '34' then
        TriggerEvent("police:client:ActiveCamera", 34)
    elseif cam == '35' then
        TriggerEvent("police:client:ActiveCamera", 35)
    elseif cam == '36' then
        TriggerEvent("police:client:ActiveCamera", 36)
    elseif cam == '37' then
        TriggerEvent("police:client:ActiveCamera", 37)
    elseif cam == '38' then
        TriggerEvent("police:client:ActiveCamera", 38)
    elseif cam == '39' then
        TriggerEvent("police:client:ActiveCamera", 39)
    elseif cam == '40' then
        TriggerEvent("police:client:ActiveCamera", 40)
    elseif cam == '41' then
        TriggerEvent("police:client:ActiveCamera", 41)
    elseif cam == '42' then
        TriggerEvent("police:client:ActiveCamera", 42)
    elseif cam == '43' then
        TriggerEvent("police:client:ActiveCamera", 43)
    elseif cam == '44' then
        TriggerEvent("police:client:ActiveCamera", 44)
    elseif cam == '45' then
        TriggerEvent("police:client:ActiveCamera", 45)
    end
end)





-- RegisterNetEvent('qb-police:cammenu', function(data)
--     exports['qb-menu']:openMenu({
--         {
            
--             header = "مراقبة كميرات المدينة",
--             isMenuHeader = true, -- Set to true to make a nonclickable title
--         },
--         {
            
--             header = "CAM 1",
--             params = {
--                 event = "police:store:cams",
--                 args = {
--                     cam = '1',
--                 }
--         } 

--         },
--         {
--             header = "Close",
--             params = {
--                 event = "qb-menu:closeMenu"
-- }      
--   },
--     })
-- end)



RegisterNetEvent('qb-police:cammenu')
AddEventHandler('qb-police:cammenu', function()
    exports['qb-menu']:openMenu({
        {
            id = 1,
            header = "Police Camera",
            isMenuHeader = true

        },
        {
            id = 2,
            header = "Stores Cameras",
            icon = "fad fa-store",
            txt = "All of Store Cams",
            params = {
                event = 'police:dispatch:cams1',
                txt = "",
            }
        },
        {
            id = 3,
            header = "SamllBanks Cameras",
            icon = "fas fa-money-check-alt",
            txt = "All of SamllBanks Cams",
            params = {
                event = 'police:dispatch:cams2',
                txt = "",
            }
        },
        {
            id = 4,
            header = "Big Banks Cameras",
            icon = "fad fa-university",
            txt = "All of Big Banks Cams",
            params = {
                event = 'police:dispatch:cams3',
                txt = "",
            }
        },
        {
            id = 5,
            header = "Jewellery Cameras",
            icon = "fad fa-gem",
            txt = "All of Jewellery Cams",
            params = {
                event = 'police:dispatch:cams4',
                txt = "",
            }
        },
        {
            id = 6,
            header = "Maybe later..",
            txt = "Here You Can Close The Menu And Come Back Soon",
            icon = "fa-duotone fa-clock",
            params = {
                 event = "qb-menu:closeMenu"
            }
        },
    })
end)



RegisterNetEvent('police:dispatch:cams1')
AddEventHandler('police:dispatch:cams1', function(pd)
exports['qb-menu']:openMenu({
        {
            id = 1,
            header = "Store Cameras",
            txt = "Stores Cams",
        },
        {
            id = 2,
            header = "Cam4",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '4',
                }
            }
        },
        {
            id = 3,
            header = "Cam5",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '5',
                }
            }
        },
        {
            id = 4,
            header = "Cam6",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '6',
                }
            }
        },
        {
            id = 5,
            header = "Cam7",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '7',
                }
            }
        },
        {
            id = 6,
            header = "Cam8",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '8',
                }
            }
        },
        {
            id = 7,
            header = "Cam9",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '9',
                }
            }
        },
        {
            id = 8,
            header = "Cam10",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '10',
                }
            }
        },
        {
            id = 9,
            header = "Cam11",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '11',
                }
            }
        },
        {
            id = 10,
            header = "Cam12",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '12',
                }
            }
        },
        {
            id = 11,
            header = "Cam13",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '13',
                }
            }
        },
        {
            id = 12,
            header = "Cam14",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '14',
                }
            }
        },
        {
            id = 13,
            header = "Cam15",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '15',
                }
            }
        },

        {
            id = 14,
            header = "Cam16",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '16',
                }
            }
        },


        {
            id = 15,
            header = "Cam17",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '17',
                }
            }
        },
        
        {
            id = 16,
            header = "Cam18",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '18',
                }
            }
        },
        
        {
            id = 17,
            header = "Cam19",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '19',
                }
            }
        },
        
        {
            id = 18,
            header = "Cam20",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '20',
                }
            }
        },

        {
            id = 19,
            header = "Cam27",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '27',
                }
            }
        },
        {
            id = 20,
            header = "Cam28",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '28',
                }
            }
        },
        {
            id = 21,
            header = "Cam29",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '29',
                }
            }
        },
        {
            id = 22,
            header = "Cam30",
            txt = "",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '30',
                }
            }
        },

        -- {
        --     id = 23,
        --     header = "Cam44",
        --     txt = "",
        --     params = {
        --         event = 'police:store:cams',
        --         txt = "",
        --         args = {
        --             cam = '44',
        --         }
        --     }
        -- },
        -- {
        --     id = 24,
        --     header = "Cam45",
        --     txt = "",
        --     params = {
        --         event = 'police:store:cams',
        --         txt = "",
        --         args = {
        --             cam = '45',
        --         }
        --     }
        -- },
       
        {
            id = 23,
            header = "Return",
            txt = "",
            params = {
                event = 'qb-police:cammenu',
            }
        },
        {
            id = 24,
            header = "Exit",
            txt = "",
            params = {
                 event = "qb-menu:closeMenu"
            }
        },
    })
end)




RegisterNetEvent('police:dispatch:cams2')
AddEventHandler('police:dispatch:cams2', function(cam)
exports['qb-menu']:openMenu({
        {
            id = 1,
            header = "Small Banks Cams",
            txt = "All City Cams",
        },
        {
            id = 2,
            header = "Cam21",
            txt = "Fleeca Bank Hawick Ave CAM#1",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '21',
                }
            }
        },
        {
            id = 3,
            header = "Cam22",
            txt = "Fleeca Bank Legion Square CAM#1",
            params = {
                event = 'police:store:cams',
                args = {
                    cam = '22',
                }
            }
        },
        {
            id = 4,
            header = "Cam23",
            txt = "Fleeca Bank Hawick Ave CAM#2",
            params = {
                event = 'police:store:cams',
                args = {
                    cam = '23',
                }
            }
        },
        {
            id = 5,
            header = "Cam24",
            txt = "Fleeca Bank Del Perro Blvd CAM#1",
            params = {
                event = 'police:store:cams',
                args = {
                    cam = '24',
                }
            }
        },
        {
            id = 6,
            header = "Cam25",
            txt = "Fleeca Bank Del Perro Blvd CAM#1",
            params = {
                event = 'police:store:cams',
                args = {
                    cam = '25',
                }
            }
        },
        {
            id = 7,
            header = "Cam43",
            txt = "Fleeca Bank Sandy Shores CAM#1",
            params = {
                event = 'police:store:cams',
                args = {
                    cam = '43',
                }
            }
        },
        {
            id = 8,
            header = "Return",
            txt = "",
            params = {
                event = 'qb-police:cammenu',
            }
        },
        {
            id = 9,
            header = "Exit",
            txt = "",
            params = {
                 event = "qb-menu:closeMenu"
            }
        },

    })
end)


RegisterNetEvent('police:dispatch:cams3')
AddEventHandler('police:dispatch:cams3', function(cam)
exports['qb-menu']:openMenu({
        {
            id = 1,
            header = "Big Banks Cams",
            txt = "All City Cams",
        },
        {
            id = 2,
            header = "Cam1",
            txt = "Pacific Bank CAM#1",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '1',
                }
            }
        },
        {
            id = 3,
            header = "Cam2",
            txt = "Pacific Bank CAM#2",
            params = {
                event = 'police:store:cams',
                args = {
                    cam = '2',
                }
            }
        },
        {
            id = 4,
            header = "Cam3",
            txt = "Pacific Bank CAM#3",
            params = {
                event = 'police:store:cams',
                args = {
                    cam = '3',
                }
            }
        },
        {
            id = 5,
            header = "Cam26",
            txt = "Paleto Bank CAM#1",
            params = {
                event = 'police:store:cams',
                args = {
                    cam = '26',
                }
            }
        },
        
        {
            id = 14,
            header = "Return",
            txt = "",
            params = {
                event = 'qb-police:cammenu',
            }
        },
        {
            id = 15,
            header = "Exit",
            txt = "",
            params = {
                 event = "qb-menu:closeMenu"
            }
        },

    })
end)


RegisterNetEvent('police:dispatch:cams4')
AddEventHandler('police:dispatch:cams4', function(cam)
exports['qb-menu']:openMenu({
        {
            id = 1,
            header = "Big Banks Cams",
            txt = "All City Cams",
        },
        {
            id = 2,
            header = "Cam31",
            txt = "Vangelico Juwelier CAM#1",
            params = {
                event = 'police:store:cams',
                txt = "",
                args = {
                    cam = '31',
                }
            }
        },
        {
            id = 3,
            header = "Cam32",
            txt = "Vangelico Juwelier CAM#2",
            params = {
                event = 'police:store:cams',
                args = {
                    cam = '32',
                }
            }
        },
        {
            id = 4,
            header = "Cam33",
            txt = "Vangelico Juwelier CAM#3",
            params = {
                event = 'police:store:cams',
                args = {
                    cam = '33',
                }
            }
        },
        {
            id = 5,
            header = "Cam34",
            txt = "Vangelico Juwelier CAM#4",
            params = {
                event = 'police:store:cams',
                args = {
                    cam = '34',
                }
            }
        },
        
        {
            id = 6,
            header = "Exit",
            txt = "",
            params = {
                event = 'qb-police:cammenu',
            }
        },
        {
            id = 7,
            header = "Exit",
            txt = "",
            params = {
           event = "qb-menu:closeMenu"
}
        },

    })
end)
