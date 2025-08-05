import asyncio
import calendar
import itertools
import typing
from collections.abc import Generator
from typing import NamedTuple, TypedDict

import dns.rdtypes.ANY.TXT
from dns import resolver
from dns.rdatatype import RdataType
from dns.asyncresolver import canonical_name, resolve
from dns.rrset import RRset

from aws_lambda_powertools import Logger

log = Logger()


def iter_year_month(start_year: int, end_year: int) -> Generator[tuple[int, int]]:
    for year in range(start_year, end_year):
        for month in range(1, 13):
            yield year, month


def iter_year_month_day(
    start_year: int, end_year: int
) -> Generator[tuple[int, int, int]]:
    for year in range(start_year, end_year):
        for month in range(1, 13):
            for y, m, d in calendar.Calendar().itermonthdays3(year, month):
                yield y, m, d


dkim_selectors: list[str] = (
    [
        "google",
        "default",
        "mail",
        "class",
        "dkim",
        "prod",
        "selector",
        "dk",
        "main",
        "test",
        "postfix",
        "0xdeadbeef",
        "proddkim",
        "pub",
        "pubkey",
        "publickey",
        "sasl",
        "mandrill",
        "smtpapi",
        "mx",
        "cm",
        "mailo",
    ]
    # + [f"s{i}" for i in range(0, 10)]
    # + [f"s-{i}" for i in range(0, 10)]
    # + [f"dk{i}" for i in range(0, 21)]
    # + [f"dkim{i}" for i in range(0, 21)]
    # + [f"dkim{i}" for i in range(0, 21)]
    # + [f"sel{i}" for i in range(0, 10)]
    # + [f"sel-{i}" for i in range(0, 10)]
    # + [f"key{i}" for i in range(0, 10)]
    # + [f"k{i}" for i in range(0, 10)]
    # + [f"key{i}" for i in range(0, 10)]
    # + [f"selector{i}" for i in range(0, 10)]
    # + [f"v{i}" for i in range(0, 10)]
    # + [f"hs{i}" for i in range(0, 10)]
    + [f"purelymail{i}" for i in range(0, 10)]
    # + [
    #     f"{year}{str(month).zfill(2)}"
    #     for year, month in iter_year_month(2015, datetime.now().year)
    # ]
    # + [
    #     f"{str(month).zfill(2)}{year}"
    #     for year, month in iter_year_month(2015, datetime.now().year)
    # ]
    # + [
    #     f"{year}{list(calendar.month_name)[month].lower()}"
    #     for year, month in iter_year_month(2015, datetime.now().year)
    # ]
    # + [
    #     f"{year}{list(calendar.month_abbr)[month].lower()}"
    #     for year, month in iter_year_month(2015, datetime.now().year)
    # ]
    # + [
    #     f"{year}{month}{day}"
    #     for year, month, day in iter_year_month_day(2015, datetime.now().year)
    # ]
    # + [
    #     f"{day}{month}{year}"
    #     for year, month, day in iter_year_month_day(2015, datetime.now().year)
    # ]
)


dkim_subdomains = [
    "_domainkey",
    "dkimroot",
]

selectors = [
    f"{s[0]}.{s[1]}" for s in itertools.product(dkim_selectors, dkim_subdomains)
]


class DkimRecord(TypedDict):
    qname: str
    cname: str
    value: str
    ttl: int


class ScrapedDkimKey(NamedTuple):
    qname: str
    cname: str
    rrsets: list[RRset]

    def to_dkim_record(self) -> DkimRecord:
        rrset = self.rrsets[0]
        txt: dns.rdtypes.ANY.TXT.TXT = typing.cast(dns.rdtypes.ANY.TXT.TXT, rrset[0])
        value = " ".join(f'"{s.decode("utf-8")}"' for s in txt.strings)
        return DkimRecord(
            qname=self.qname,
            cname=self.cname,
            value=value,
            ttl=rrset.ttl,
        )


async def scrape_dkim_record(
    qname: str,
) -> ScrapedDkimKey | None:
    c_qname = await canonical_name(qname)
    log.debug(
        f"Qname '{qname}' had canonical name '{c_qname}'", qname=qname, cname=c_qname
    )
    try:
        res = (await resolve(c_qname, RdataType.TXT)).response.answer
        return ScrapedDkimKey(qname, c_qname.to_unicode(), res)
    except (resolver.NXDOMAIN, resolver.LifetimeTimeout) as e:
        log.debug(
            f"Failed to get dkim record for qname: '{qname}'",
            err=e,
            qname=qname,
            cname=c_qname,
        )
        return None


async def scrape_dkim_selectors(
    domain: str,
) -> list[ScrapedDkimKey]:
    res: list[ScrapedDkimKey] = []

    max_concurrent_scrapes_sem = asyncio.Semaphore(512)

    async def _scrape(qname: str):
        async with max_concurrent_scrapes_sem:
            log.debug("Scraping qname", qname=qname)
            scraped_record = await scrape_dkim_record(qname)
            log.info(
                "Finished scraping records for qname",
                qname=qname,
                record=scraped_record,
            )
            if scraped_record and len(scraped_record.rrsets) > 0:
                log.debug(f"Found DKIM records for qname '{qname}'", qname=qname)
                res.append(scraped_record)

    jobs = [_scrape(f"{selector}.{domain}") for selector in selectors]
    _ = await asyncio.gather(*jobs)

    return res
