<?php

namespace App\Filament\Admin\Resources;

use App\Filament\Admin\Resources\ServerResource\Pages;
use App\Models\Server;
use Filament\Resources\Resource;
use Illuminate\Database\Eloquent\Builder;

class ServerResource extends Resource
{
    protected static ?string $model = Server::class;

    protected static ?string $navigationIcon = 'tabler-brand-docker';

    protected static ?string $recordTitleAttribute = 'name';

    public static function getNavigationLabel(): string
    {
        return trans('admin/server.nav_title');
    }

    public static function getModelLabel(): string
    {
        return trans('admin/server.model_label');
    }

    public static function getPluralModelLabel(): string
    {
        return trans('admin/server.model_label_plural');
    }

    public static function getNavigationGroup(): ?string
    {
        return config('panel.filament.top-navigation', false) ? null : trans('admin/dashboard.server');
    }

    public static function getNavigationBadge(): ?string
    {
        return (string) static::getEloquentQuery()->count() ?: null;
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListServers::route('/'),
            'create' => Pages\CreateServer::route('/create'),
            'edit' => Pages\EditServer::route('/{record}/edit'),
        ];
    }

    public static function getEloquentQuery(): Builder
    {
        $query = parent::getEloquentQuery();

        return $query->whereHas('node', function (Builder $query) {
            $query->whereIn('id', auth()->user()->accessibleNodes()->pluck('id'));
        });
    }
}
