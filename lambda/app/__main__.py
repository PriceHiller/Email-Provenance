from app.main import router


if __name__ == "__main__":
    res = router({"domain": "pricehiller.com", "endpoint": "scrape"}, None)  # pyright: ignore[reportArgumentType]
    res = router({"endpoint": "rescrape"}, None)  # pyright: ignore[reportArgumentType]
    print(res)
